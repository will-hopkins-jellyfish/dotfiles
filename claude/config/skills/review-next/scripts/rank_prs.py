#!/usr/bin/env python3
"""Rank open PRs by how useful they are for me to review next.

Sweeps every open non-draft PR in the org, classifies each into a priority tier,
scores it for actionability within that tier, and prints the queue. Tier always
dominates the sort; score only breaks ties inside a tier.

Usage:
    rank_prs.py                 # top pick plus runners-up
    rank_prs.py --top 10
    rank_prs.py --json
    rank_prs.py --tier 1        # only Data Foundations
    rank_prs.py --repo infra
    rank_prs.py --show-skipped  # explain what was filtered out and why
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL_DIR = HERE.parent
CONFIG_PATH = SKILL_DIR / "config.json"
CACHE_DIR = SKILL_DIR / ".cache"
TEAM_CACHE_TTL = 24 * 3600
SWEEP_CACHE_TTL = 900

PAGE_SIZE = 25
MAX_PAGES = 40
GQL_RETRIES = 4

SWEEP_QUERY = """
query($q: String!, $after: String) {
  search(query: $q, type: ISSUE, first: %d, after: $after) {
    issueCount
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on PullRequest {
        number title url isDraft createdAt updatedAt
        additions deletions changedFiles
        author { login __typename }
        repository { name nameWithOwner }
        headRefName
        reviewDecision
        mergeable
        labels(first: 10) { nodes { name } }
        reviewRequests(first: 10) {
          nodes { requestedReviewer { __typename ... on User { login } ... on Team { slug } } }
        }
        latestReviews(first: 10) { nodes { author { login } state submittedAt } }
        commits(last: 1) {
          nodes { commit { committedDate statusCheckRollup { state } } }
        }
      }
    }
  }
}
""" % PAGE_SIZE


# ---------------------------------------------------------------- shell / api

def sh(args, **kw):
    r = subprocess.run(args, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.exit(f"command failed: {' '.join(args)}\n{r.stderr.strip()}")
    return r.stdout


def gql(query, variables):
    """Run a GraphQL query, retrying the 502s GitHub returns on costly searches."""
    payload = json.dumps({"query": query, "variables": variables})
    last = ""
    for attempt in range(GQL_RETRIES):
        r = subprocess.run(
            ["gh", "api", "graphql", "--input", "-"],
            input=payload, capture_output=True, text=True,
        )
        if r.returncode == 0:
            data = json.loads(r.stdout)
            if "errors" in data:
                sys.exit("GitHub GraphQL errors:\n" + json.dumps(data["errors"], indent=2))
            return data["data"]
        last = r.stderr.strip()
        if not any(c in last for c in ("502", "503", "504", "timeout")):
            break
        time.sleep(2 ** attempt)
    sys.exit(f"GitHub GraphQL call failed:\n{last}")


def search_urls(query):
    """URL set for a search query, using the cheap REST search."""
    out = sh(["gh", "api", "-X", "GET", "search/issues",
              "-f", f"q={query}", "-f", "per_page=100",
              "--paginate", "--jq", ".items[].html_url"])
    return {line.strip() for line in out.splitlines() if line.strip()}


# ------------------------------------------------------------------- identity

def load_config():
    if not CONFIG_PATH.exists():
        sys.exit(f"missing config: {CONFIG_PATH}")
    return json.loads(CONFIG_PATH.read_text())


def whoami():
    return json.loads(sh(["gh", "api", "user"]))["login"]


def cached_json(name, ttl, producer):
    CACHE_DIR.mkdir(exist_ok=True)
    path = CACHE_DIR / name
    if path.exists() and (time.time() - path.stat().st_mtime) < ttl:
        try:
            return json.loads(path.read_text())
        except json.JSONDecodeError:
            pass
    value = producer()
    path.write_text(json.dumps(value, indent=2))
    return value


def team_members(org, slug):
    out = sh(["gh", "api", f"orgs/{org}/teams/{slug}/members",
              "--paginate", "--jq", ".[].login"])
    return sorted(line.strip() for line in out.splitlines() if line.strip())


def my_team_slugs(org):
    out = sh(["gh", "api", "user/teams", "--paginate",
              "--jq", f'.[] | select(.organization.login=="{org}") | .slug'])
    return sorted(line.strip() for line in out.splitlines() if line.strip())


# ------------------------------------------------------------------ utilities

def parse_ts(value):
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def days_since(value, now):
    ts = parse_ts(value)
    return (now - ts).total_seconds() / 86400 if ts else 0.0


def normalize(text):
    """Collapse to space-delimited words so keywords match on word boundaries.

    Naive substring matching promoted a 'datadog-crds' dependency bump as an
    'rds' hit; normalizing both sides and padding with spaces stops that.
    """
    return " " + re.sub(r"[^a-z0-9]+", " ", text.lower()).strip() + " "


def keyword_hit(text, keywords):
    hay = normalize(text)
    for kw in keywords:
        if normalize(kw) in hay:
            return kw
    return None


def ticket_prefixes(title, branch):
    """Ticket prefixes found in a title or branch, e.g. {'DF', 'CF'}."""
    text = f"{title} {branch or ''}"
    return {m.upper() for m in re.findall(r"\b([A-Za-z]{2,12})-\d+\b", text)}


# ------------------------------------------------------------------- fetching

def _fetch_all_pages(q):
    """Walk one cursor chain to exhaustion."""
    nodes, cursor, pages = [], None, 0
    while pages < MAX_PAGES:
        data = gql(SWEEP_QUERY, {"q": q, "after": cursor})["search"]
        nodes.extend(n for n in data["nodes"] if n)
        pages += 1
        if not data["pageInfo"]["hasNextPage"]:
            break
        cursor = data["pageInfo"]["endCursor"]
    return nodes


def _shards(base, now):
    """Split the sweep into disjoint date windows so they can run in parallel.

    One cursor chain over ~350 PRs takes over a minute; four shorter chains
    running concurrently cut that to roughly a quarter.
    """
    d = now.date()
    b1, b2, b3 = d - timedelta(days=7), d - timedelta(days=21), d - timedelta(days=60)
    day = timedelta(days=1)
    return [
        f"{base} updated:>={b1}",
        f"{base} updated:{b2}..{b1 - day}",
        f"{base} updated:{b3}..{b2 - day}",
        f"{base} updated:<{b3}",
    ]


def sweep(org, me, include_drafts, verbose, ttl, now):
    base = f"org:{org} is:pr is:open -author:{me}"
    if not include_drafts:
        base += " draft:false"

    def fetch():
        queries = _shards(base, now)
        with ThreadPoolExecutor(max_workers=len(queries)) as ex:
            batches = list(ex.map(_fetch_all_pages, queries))
        merged = {}
        for batch in batches:
            for n in batch:
                merged[n["url"]] = n
        return list(merged.values())

    if verbose:
        print(f"Sweeping open PRs in {org}...", file=sys.stderr)
    key = "sweep-%s.json" % hashlib.sha1(base.encode()).hexdigest()[:10]
    prs = cached_json(key, ttl, fetch)
    if verbose:
        print(f"  {len(prs)} open PRs from other authors", file=sys.stderr)
    return prs


# ---------------------------------------------------------------- classifying

def classify(pr, ctx):
    """Attach tier, signals and score to a PR. Returns an enriched dict."""
    cfg, w, now, me = ctx["config"], ctx["config"]["weights"], ctx["now"], ctx["me"]

    author = (pr.get("author") or {}).get("login") or "ghost"
    repo = pr["repository"]["name"]
    title = pr["title"]
    branch = pr.get("headRefName") or ""
    prefixes = ticket_prefixes(title, branch)

    # --- who has been asked to review
    requested_users, requested_teams = set(), set()
    for node in pr["reviewRequests"]["nodes"]:
        rr = node.get("requestedReviewer") or {}
        if rr.get("__typename") == "User":
            requested_users.add(rr["login"])
        elif rr.get("__typename") == "Team":
            requested_teams.add(rr["slug"])

    requested_me = me in requested_users
    requested_my_team = bool(requested_teams & ctx["my_teams"])

    # --- my own review history on this PR
    my_review, my_review_at = None, None
    for r in pr["latestReviews"]["nodes"]:
        if (r.get("author") or {}).get("login") == me:
            my_review, my_review_at = r["state"], parse_ts(r["submittedAt"])

    head = (pr["commits"]["nodes"] or [{}])[0].get("commit") or {}
    head_at = parse_ts(head.get("committedDate"))
    ci = ((head.get("statusCheckRollup") or {}).get("state") or "NONE").upper()

    pushed_since_my_review = bool(
        my_review and my_review_at and head_at and head_at > my_review_at
    )

    # --- tier assignment (lowest matching tier wins)
    signals, tier, tier_label = [], None, None

    def team_tier(num):
        spec = cfg["tiers"].get(str(num))
        if not spec:
            return False, None
        members = ctx["teams"].get(spec["github_team"], set())
        by_author = author in members
        by_ticket = bool(prefixes & {p.upper() for p in spec["ticket_prefixes"]})
        if by_author and by_ticket:
            why = f"{spec['label']} author + {'/'.join(sorted(prefixes & {p.upper() for p in spec['ticket_prefixes']}))} ticket"
        elif by_author:
            why = f"{spec['label']} teammate ({author})"
        elif by_ticket:
            why = f"{'/'.join(sorted(prefixes & {p.upper() for p in spec['ticket_prefixes']}))} ticket"
        else:
            return False, None
        return True, why

    # --- tier 2 signals: does this need me specifically?
    exp = cfg["expertise"]
    kw_hit = keyword_hit(f"{title} {branch}", exp["keywords"])
    expertise = None
    if repo in exp["repos"]:
        expertise = f"{repo} is one of my areas"
    elif repo in exp["scoped_repos"] and kw_hit:
        expertise = f"{repo} touching '{kw_hit}'"
    elif kw_hit:
        expertise = f"mentions '{kw_hit}'"

    needs_me = []
    if requested_me:
        needs_me.append("review requested from me by name")
    if pr["url"] in ctx["mentioned"]:
        needs_me.append("I'm @-mentioned")
    if pushed_since_my_review:
        needs_me.append(f"I left a {my_review.lower().replace('_', ' ')} review; new commits since")
    if expertise:
        needs_me.append(expertise)

    hit1, why1 = team_tier(1)
    hit3, why3 = team_tier(3)

    if hit1:
        tier, tier_label, primary = 1, cfg["tiers"]["1"]["label"], why1
    elif needs_me:
        tier, tier_label, primary = 2, "Needs my input", needs_me[0]
    elif hit3:
        tier, tier_label, primary = 3, cfg["tiers"]["3"]["label"], why3
    elif requested_me or requested_my_team:
        via = "me" if requested_me else "/".join(sorted(requested_teams & ctx["my_teams"]))
        tier, tier_label, primary = 4, "Other review requests", f"review requested via {via}"
    else:
        return None  # out of scope entirely

    signals = needs_me + ([primary] if primary not in needs_me else [])

    # --- hard skips
    decision = pr.get("reviewDecision")
    quiet = days_since(pr["updatedAt"], now)
    skip = None
    if my_review and not pushed_since_my_review:
        skip = f"I already reviewed it ({my_review.lower()}), no new commits"
    elif decision == "APPROVED" and not requested_me and not requested_my_team:
        skip = "already approved, my review isn't blocking"
    elif quiet > cfg["filters"]["abandoned_after_quiet_days"]:
        skip = f"untouched for {quiet:.0f} days, looks abandoned"

    # --- score within tier
    score = 0.0
    if requested_me:
        score += w["requested_me_directly"]
    if pr["url"] in ctx["mentioned"]:
        score += w["mentioned_me"]
    if pushed_since_my_review:
        score += w["rereview_after_my_comments"]
    if expertise:
        score += w["expertise_match"]
    if requested_my_team and not requested_me:
        score += w["requested_my_team"]

    score += {"SUCCESS": w["ci_success"], "FAILURE": w["ci_failure"],
              "ERROR": w["ci_failure"], "PENDING": w["ci_pending"],
              "EXPECTED": w["ci_pending"]}.get(ci, 0)

    if pr.get("mergeable") == "CONFLICTING":
        score += w["conflicting"]
    if decision == "CHANGES_REQUESTED":
        score += w["changes_requested"]
    if decision == "APPROVED":
        score += w["already_approved_by_others"]

    age = days_since(pr["createdAt"], now)
    score += min(age, w["age_days_cap"]) * w["age_per_day"]
    if quiet > w["quiet_penalty_after_days"]:
        score += w["quiet_penalty"]

    lines = pr["additions"] + pr["deletions"]
    if lines <= w["small_pr_max_lines"]:
        score += w["small_pr_bonus"]
    elif lines >= w["huge_pr_min_lines"]:
        score += w["huge_pr_penalty"]

    labels = [l["name"] for l in pr["labels"]["nodes"]]
    is_bot = ((pr.get("author") or {}).get("__typename") == "Bot"
              or author.endswith("-bot") or author.endswith("[bot]"))

    return {
        "tier": tier, "tier_label": tier_label, "score": round(score, 1),
        "repo": pr["repository"]["nameWithOwner"], "number": pr["number"],
        "title": title, "url": pr["url"], "author": author, "is_bot": is_bot,
        "ci": ci, "decision": decision or "NONE",
        "mergeable": pr.get("mergeable"), "labels": labels,
        "additions": pr["additions"], "deletions": pr["deletions"],
        "changed_files": pr["changedFiles"],
        "age_days": round(age, 1), "quiet_days": round(quiet, 1),
        "requested_me": requested_me, "requested_teams": sorted(requested_teams),
        "signals": signals, "skip": skip,
    }


# ------------------------------------------------------------------ rendering

def fmt_row(p, idx=None):
    bits = [f"{p['repo'].split('/')[-1]}#{p['number']}"]
    head = f"{idx}. " if idx else ""
    ci = {"SUCCESS": "CI green", "FAILURE": "CI FAILING", "ERROR": "CI ERROR",
          "PENDING": "CI running", "NONE": "no CI"}.get(p["ci"], p["ci"])
    meta = [f"@{p['author']}" + (" [bot]" if p["is_bot"] else ""),
            f"+{p['additions']}/-{p['deletions']} in {p['changed_files']}f",
            ci, f"{p['age_days']:.0f}d old"]
    if p["mergeable"] == "CONFLICTING":
        meta.append("CONFLICTS")
    if p["decision"] == "CHANGES_REQUESTED":
        meta.append("changes requested")
    if p["decision"] == "APPROVED":
        meta.append("already approved")
    return (f"{head}{bits[0]}  {p['title']}\n"
            f"   {' · '.join(meta)}\n"
            f"   why: {'; '.join(p['signals'][:3])}\n"
            f"   {p['url']}")


def collapse(ranked, cap):
    """Cap how many PRs one author contributes, so a batch of near-identical
    PRs can't crowd out everything else. Returns (shown, held_counts)."""
    if cap <= 0:
        return ranked, {}
    shown, seen, held = [], {}, {}
    for p in ranked:
        a = p["author"]
        seen[a] = seen.get(a, 0) + 1
        if seen[a] <= cap:
            shown.append(p)
        else:
            held[a] = held.get(a, 0) + 1
    return shown, held


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", type=int, default=5, help="how many to list (default 5)")
    ap.add_argument("--tier", type=int, action="append", help="restrict to tier(s)")
    ap.add_argument("--repo", help="restrict to a repo name substring")
    ap.add_argument("--author", help="restrict to an author")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--show-skipped", action="store_true", help="also list filtered-out PRs")
    ap.add_argument("--include-drafts", action="store_true")
    ap.add_argument("--refresh", action="store_true", help="ignore all caches and refetch")
    ap.add_argument("--cache-ttl", type=int, default=SWEEP_CACHE_TTL,
                    help=f"seconds to reuse the fetched PR sweep (default {SWEEP_CACHE_TTL})")
    ap.add_argument("--per-author", type=int, default=2,
                    help="max PRs shown per author before collapsing (0 = no cap)")
    ap.add_argument("--quiet", action="store_true", help="suppress progress output")
    args = ap.parse_args()

    cfg = load_config()
    org = cfg["org"]
    verbose = not args.quiet and not args.json

    if verbose:
        print("Resolving identity and teams...", file=sys.stderr)
    me = whoami()
    ttl = 0 if args.refresh else TEAM_CACHE_TTL

    teams = {}
    for spec in cfg["tiers"].values():
        slug = spec["github_team"]
        teams[slug] = set(cached_json(f"team-{slug}.json", ttl,
                                      lambda s=slug: team_members(org, s)))
    my_teams = set(cached_json("my-teams.json", ttl, lambda: my_team_slugs(org)))

    now = datetime.now(timezone.utc)
    sweep_ttl = 0 if args.refresh else args.cache_ttl
    prs = sweep(org, me, args.include_drafts, verbose, sweep_ttl, now)

    mentioned = cached_json(
        "mentions.json", sweep_ttl,
        lambda: sorted(search_urls(f"org:{org} is:pr is:open mentions:{me} -author:{me}")))

    ctx = {"config": cfg, "me": me, "teams": teams, "my_teams": my_teams,
           "mentioned": set(mentioned), "now": now}

    ranked, skipped = [], []
    for pr in prs:
        row = classify(pr, ctx)
        if row is None:
            continue
        (skipped if row["skip"] else ranked).append(row)

    def keep(p):
        if args.tier and p["tier"] not in args.tier:
            return False
        if args.repo and args.repo.lower() not in p["repo"].lower():
            return False
        if args.author and args.author.lower() != p["author"].lower():
            return False
        return True

    ranked = sorted([p for p in ranked if keep(p)],
                    key=lambda p: (p["tier"], -p["score"]))
    skipped = [p for p in skipped if keep(p)]

    if args.json:
        print(json.dumps({"me": me, "considered": len(prs),
                          "queue": ranked, "skipped": skipped}, indent=2))
        return

    if not ranked:
        print("Nothing in the review queue. Considered "
              f"{len(prs)} open PRs; {len(skipped)} were filtered out.")
        if args.show_skipped:
            for p in skipped:
                print(f"  - {p['repo']}#{p['number']}: {p['skip']}")
        return

    counts = {}
    for p in ranked:
        counts[p["tier_label"]] = counts.get(p["tier_label"], 0) + 1
    summary = ", ".join(f"{v} {k}" for k, v in sorted(counts.items()))

    shown, held = collapse(ranked, args.per_author)

    print(f"\n{'=' * 72}\nNEXT UP\n{'=' * 72}")
    print(fmt_row(shown[0]))
    print(f"\n   tier {shown[0]['tier']} ({shown[0]['tier_label']}) · score {shown[0]['score']}")

    rest = shown[1:args.top]
    if rest:
        print(f"\n{'-' * 72}\nTHEN\n{'-' * 72}")
        for i, p in enumerate(rest, start=2):
            print(fmt_row(p, idx=i) + f"\n   tier {p['tier']} ({p['tier_label']}) · score {p['score']}\n")

    if held:
        note = ", ".join(f"{n} more from @{a}" for a, n in sorted(held.items(), key=lambda kv: -kv[1]))
        print(f"collapsed: {note}  (--per-author 0 to show all)\n")

    print(f"{len(ranked)} in queue ({summary}) · "
          f"{len(skipped)} filtered · {len(prs)} open PRs considered")

    if args.show_skipped and skipped:
        print(f"\n{'-' * 72}\nFILTERED OUT\n{'-' * 72}")
        for p in sorted(skipped, key=lambda x: x["tier"]):
            print(f"  {p['repo']}#{p['number']} ({p['tier_label']}): {p['skip']}")


if __name__ == "__main__":
    main()
