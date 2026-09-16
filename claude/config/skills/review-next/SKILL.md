---
name: review-next
description: >-
  Pick the next most useful open PR for Will to review, from other authors
  across the Jellyfish-AI org. Use whenever he asks what to review next, what's
  in his review queue, whether anything needs his review, what he should look at
  now, what's blocking other people, or asks to be walked through his review
  backlog — including phrasings like "what should I review next?", "anything
  for me to review?", "next PR", "my review queue", "what's waiting on me?",
  "give me a DF PR to review", or "what did I miss while I was out?". Ranks by
  Data Foundations first, then PRs that need Will specifically, then Core
  Foundations, then anything else he's a requested reviewer on.
---

# What should I review next?

Ranks every open PR in `Jellyfish-AI` from other authors, drops the ones that
aren't actionable, and returns the single best next review — plus what follows it.

## Run it

```bash
export PATH=/opt/homebrew/bin:$PATH
python3 ~/.claude/skills/review-next/scripts/rank_prs.py --top 5
```

**Run with `dangerouslyDisableSandbox: true`.** `gh` cannot work inside the
Seatbelt sandbox here: the keychain lookup fails ("token in keyring is invalid")
and the filtering proxy breaks TLS (`x509: OSStatus -26276`). Both look like
auth problems and are not — do not tell Will to re-run `gh auth refresh`.

Useful flags:

| Flag | Effect |
|---|---|
| `--top N` | How many to list (default 5) |
| `--tier 1` | One tier only; repeatable (`--tier 1 --tier 2`) |
| `--repo analytics-dbt` | Restrict to a repo |
| `--author punzalan` | Restrict to an author |
| `--per-author N` | Cap per author before collapsing (default 2, `0` = all) |
| `--show-skipped` | List what was filtered out, with the reason |
| `--json` | Machine-readable, for follow-up filtering |
| `--refresh` | Bust all caches and refetch |

First run of the day takes ~25s; results are cached for 15 minutes, so
follow-ups return instantly. Use `--refresh` only if Will says the data looks
stale.

## The ranking

Tier always dominates. Score only orders PRs *within* a tier.

1. **Data Foundations** — author is on the `data-foundations` GitHub team, or
   the title/branch carries a `DF-` ticket.
2. **Needs Will specifically** — review requested from him *by name* (not via a
   team), he's `@`-mentioned, he reviewed and the author has pushed since, or it
   touches his expertise areas (OpenMetadata, analytics-dbt, Databricks, RDS/IAM).
3. **Core Foundations** — `core-foundations` team author, or a `CF-` ticket.
4. **Everything else he's a requested reviewer on**, directly or via a team
   (`infra`, `dev`).

A PR lands in the **lowest-numbered tier it matches**. Anything matching no tier
never surfaces — the org has ~350 open PRs and most have nothing to do with him.

Within a tier, score rewards: a direct request, an `@`-mention, a re-review after
his comments, an expertise match, green CI, age (capped at 30 days), and a small
diff. It penalises: failing CI, merge conflicts, changes-requested, existing
approvals, and PRs gone quiet for 45+ days.

Bots are ranked on the same scale as humans, deliberately — a green one-line
Renovate bump is a legitimate quick win.

### Always filtered out

- Drafts, and Will's own PRs
- Already reviewed by him with no new commits since
- Already approved, where he isn't a pending reviewer
- Untouched for 120+ days (abandoned)

## How to present it

Lead with the **one** PR he should open now — don't make him choose from a list.
Give him, in a couple of lines: what it changes, why it's top (the `why:` line),
and anything that will slow the review down (size, failing CI, conflicts).

Then offer the natural next step rather than stopping:

- `/code-review <url>` to actually review it
- `/review-pr-comments` if it's a re-review with open threads
- "skip it" → re-run and exclude that PR
- "only DF" / "only analytics-dbt" → re-run with `--tier 1` / `--repo`

If he asks for *context* on the top PR, fetch it — `gh pr view <url> --json
body,files` (also unsandboxed) — rather than guessing from the title.

Never tell him a PR is safe to approve. Surfacing it is the job; judging it is
`/code-review`'s, or his.

## Tuning

`config.json` in this directory holds the org, the two team slugs, ticket
prefixes, expertise repos/keywords, and every scoring weight. Team rosters are
read live from GitHub and cached for 24h, so joiners and leavers are picked up
without editing anything.

Two expertise lists, deliberately: `repos` match on the repo alone, while
`scoped_repos` (`infra`, `jellyfish`, `datascience` — large and shared) also
need a keyword hit, or they'd drag in half the org.

Keywords match on **word boundaries** after punctuation is normalized to spaces.
That is what stops `rds` matching `datadog-crds`. Keep that behaviour if you edit
`keyword_hit()`.
