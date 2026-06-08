# Context
Review `~/USER.md` for context on the user and the tools they work with 

# Skills
- Check the user's ~/.claude directory for skills
- If in a git repo, check the top-level ./claude directory for skills
- Finally, check the current directory for skills

# Agent Teams
- Create the following team members as needed:
  - Planning agent
  - Implementing agents (as many as needed based on the plan)
  - Reviewing agent
  - Testing agent
- Use the details in `~/MODEL_ROUTING.md` to assign tasks to the right model
- Track the total tokens used by agent in an agent team
- The user should not communicate directly with team members
  - The agent that creates the team will be the single point of contact between the user and team members

## Planning
- Provide clear completion criteria for each task, for the reviewer agent
- Consider edge cases, but do not address every single edge case
  - Use a sub-agent to rate the likelihood of each edge case occurring, and the impact if it were to occur
  - Include all edge cases in the plan, grouped into "Must address" and "Will not address"

## Implementing
- Use agents in parallel whenever possible
- Use worktrees to isolate each agent's work
- If one agent's work will build on another, run them sequentially and reuse worktrees if there is 100% overlap

### Worktrees
- Implementation agents MUST run in isolated git worktrees (use `isolation: "worktree"` when dispatching)
- Use `.worktrees/` as the worktree directory (project-local)
- Planning and Review agents run in the main working directory (read-only, no changes needed)
- Testing agents run in the worktree where the implementation happened
- After creating a worktree, run `pdm install` to set up dependencies
- Clean up worktrees after successful merge back to the feature branch

## Reviewing
- Use a reviewer to judge the quality of the plan
- Use a reviewer to judge the success of each implementation step
- Do not continue until the reviewer confirms the step is complete
  - Use a maximum of 3 attempts before failing
  - If the reviewer judges a step to have failed, prompt the implementation agent to review what went wrong and ask the planning agent to incorporate that insight before re-prompting the implementation agent
- Use a reviewer to judge the completeness of testing

## Testing
- Use `pdm run pytest <test>` to run pytest
- If tests do not pass, use a sub-agent to revise test cases
- Continue testing and revising until tests pass
  - Use a maximum of 3 attempts before failing
 
## Pre-PR Checklist

Before creating a PR, verify:

1. **No dead code** — Remove unused imports, vestigial logic, and commented-out code
2. **DRY** — Shared logic extracted to utils/helpers, not duplicated across files
3. **Names match reality** — All file names, descriptions, and comments accurately reflect current functionality
4. **Clean commit** — No unintended files (.mcp.json, IDE configs, scratch scripts)
5. **Tight scope** — Unrelated changes belong in separate PRs
6. **Least privilege** — Permissions/access scoped to minimum needed
7. **Justify complexity** — If something isn't the simplest approach, be ready to explain why
8. **Consistent renames** — If renaming anything, rename it everywhere (files, references, docs, tests)
9. **Tests are structured** — Separate test cases, use pytest/unittest, don't re-implement app logic in tests
10. **PR description complete** — Include required context (terraform plan for infra, migration notes, etc.)

## Improvement

After each completed agent team, write a reflection file. **Reflections (and any similar meta files about the agent workflow itself) live in `~/code/datascience`, never in the project's primary repo.** They are workflow notes, not project code, and shouldn't clutter the project's commit history.

### Where the reflection file goes

- **Repo:** `~/code/datascience`
- **Path:** `user/willhopkins/<YYYY-MM-DD>-<TICKET-ID>-<short-slug>-reflection.md` — matches the existing convention in that directory (dated personal scratch files).
- **Branch:** `<TICKET-ID>-reflection` off `origin/main`, opened as a separate PR from the project's implementation PR.
- **PR body:** link the project PR (e.g. `Jellyfish-AI/jf_databricks_analytics#32`) so the two are cross-referenced.

This applies to *any* agent-workflow meta file — reflections, post-mortems, retro notes, agent-team notes. If it's about how the work was done rather than the work itself, it goes in `datascience`.

### Where the gotchas go

- **General gotchas about agent workflow, tooling, or this user's environment** → `~/AGENTS.md` (this file, in the `# Gotchas` section). These travel across all projects.
- **Project-specific gotchas** (build commands, repo conventions, deploy quirks) → that project's local `AGENTS.md` if one exists, alongside the code they describe. Open it as part of the project PR or a tiny follow-up.

### What goes in the reflection

- What went well and what went poorly
- Gotchas surfaced (and where they were promoted to — `~/AGENTS.md`, project `AGENTS.md`, or both)
- Token usage summary by agent / phase
- Highest-cost steps and whether the cost was justified by the value produced

Based on the token usage and agent self-reflection, identify potentially problematic steps and prompt the user to review.

# Gotchas

## `write` tool drops `content` for long files

### Problem
- The `write` tool takes `{path, content}` as JSON arguments. When `content` is more than ~50 lines or contains lots of escaped characters (backticks, quotes, backslashes, embedded newlines), my output occasionally emits the tool call with `path` only and `content` missing entirely.
- The pi tool harness validates args, sees no `content`, and rejects the call: `Validation failed for tool "write": content: must have required properties content`.
- Retrying with the same prompt produces the same failure deterministically — the bug is in my generation of long JSON-string arguments, not in the tool.
- Symptom in the session jsonl: a sequence of `toolCall write` entries with `keys=["path"]` and no `content` field, repeating until I notice and switch tactics.

### How to avoid
- For files larger than ~50 lines or containing many escaped characters, write via `bash` with a single-quoted heredoc instead:
  ```bash
  cat > path/to/file.py <<'EOF_PY'
  #!/usr/bin/env python3
  # ... full content here, no escaping needed for $, `, \ — single-quoted heredoc
  EOF_PY
  ```
  The single-quoted delimiter (`<<'EOF_PY'`, not `<<EOF_PY`) disables shell interpolation so backticks, dollar signs, and backslashes pass through verbatim. The JSON-encoded portion of the bash command is just the wrapping plus the body, which LLMs encode more reliably than a top-level JSON `content` field.
- For large edits to existing files, prefer multiple targeted `edit` calls (each with smaller `oldText`/`newText`) over rewriting via `write`.
- After a heredoc write, immediately `wc -l path/to/file && head -3 path/to/file && tail -3 path/to/file` to verify the file landed intact.
- If a `write` call fails once with `content: must have required properties content`, **do not retry the same `write`** — switch to the heredoc pattern. Retrying produces the same failure.

## Secrets in shell commands — use macOS Keychain, never inline

### Problem
- Every bash command I run gets logged verbatim to `~/.pi/agent/sessions/<cwd>/*.jsonl` and to the pi terminal scrollback. Anything I write on the command line — including `TOKEN=dbtu_xxx` shell-variable assignments — is captured as a literal string.
- Several Jellyfish tools store their credentials in plaintext config files: dbt Cloud (`~/.dbt/dbt_cloud.yml` — `token-value:`), Databricks PAT-style profiles, etc.
- If I read one of those files and paste the value into a bash command, I've leaked the secret into the persistent session log even if the command itself succeeds.
- Symptom: post-hoc, you find your token name (`cloud-cli-fe23`, etc.) appearing in 6–8 places across the session jsonl files. The token is then effectively burned and must be rotated.

### How to avoid
- Stash the secret in macOS Keychain once (the user does this manually so I never see the literal):
  ```bash
  security add-generic-password -a "$USER" -s "<service-name>" -w '<paste-secret-here>' -U
  ```
  Use service names like `dbt-cloud-api-token`, `databricks-prd-pat`, etc.
- In every command I write, **expand the secret inline via a subshell**:
  ```bash
  curl -H "Authorization: Token $(security find-generic-password -a "$USER" -s 'dbt-cloud-api-token' -w)" ...
  ```
  The literal value never appears on my command line; only the keychain lookup string does. The secret only exists in the curl process's memory for the duration of the request.
- **Never** do this:
  ```bash
  TOKEN=dbtu_xxx                  # NO — the literal lands in the session log
  curl -H "Authorization: Token $TOKEN" ...
  ```
- **Never** `cat ~/.dbt/dbt_cloud.yml` or similar in a command whose output I then paste back — the file's contents (including the token) end up in the session log via the tool result.
- If a tool only accepts the secret via a config file (e.g. dbt-cloud-cli reads `~/.dbt/dbt_cloud.yml` directly), keep using the config file, but do not run commands that print or grep that file's contents back to me.

### Known service-name conventions in this Keychain
- `dbt-cloud-api-token` — dbt Cloud personal API token (account `70471823498433`, host `oo516.us1.dbt.com`).
  - Expand with: `$(security find-generic-password -a "$USER" -s 'dbt-cloud-api-token' -w)`

### After a leak
- Rotate the burned secret at its source (dbt Cloud Account Settings, Databricks user settings, etc.).
- Update both the Keychain entry (`security add-generic-password ... -U`) and the tool's config file (`~/.dbt/dbt_cloud.yml`'s `token-value:`).
- Optionally scrub the historical session jsonl files of the leaked literal: `find ~/.pi/agent/sessions -name '*.jsonl' -exec grep -l '<old-token>' {} +` then sed -i replacements. (Even without scrubbing, the rotated token makes the logged copies dead.)

## Invoking subagents correctly

The `subagent` tool requires **exactly one** of three mode parameters and will reject calls that omit them with: `Invalid parameters. Provide exactly one mode.`

### Single agent (most common)
```
subagent({
  agent: "worker",        // required
  task:  "<the task>",    // required — forgetting this is the most common error
  cwd:   "/path/to/repo"  // optional, defaults to session cwd
})
```

### Parallel
```
subagent({ tasks: [{ agent, task, cwd? }, ...] })   // max 8, max 4 concurrent
```

### Chain
```
subagent({ chain: [{ agent, task, cwd? }, ...] })   // task can use {previous} placeholder
```

### Failure modes I've hit
- **`Invalid parameters. Provide exactly one mode.`** — I forgot the `task` parameter (or `tasks` / `chain`). Retrying without adding it produces the same error indefinitely. Stop and re-read this section before retrying.
- **`Agent failed: No API key found for anthropic.`** — see the "pi agent files are symlinks" gotcha below; the agent's `model:` is an Anthropic-API-style ID instead of a Bedrock localdev inference profile ARN.
- **`Agent failed: Error: Model "..." not found.`** — the agent's `model:` references a Bedrock identifier that doesn't exist in this account. Verify with `pi --list-models | grep claude`.

### Hints
- When passing a long task string, build it as a heredoc-like multi-line block in the tool args. Don't try to truncate — subagents need the full context because their session is isolated.
- **For very long task strings (~roughly 5k+ characters), the `task` parameter can silently fail to reach the tool, manifesting as the same `Invalid parameters. Provide exactly one mode.` error as forgetting it.** Workaround: write the prompt to `/tmp/<ticket>-<phase>.md` using `bash` heredocs (`cat > /tmp/foo.md <<'TASK' ... TASK`, then `cat >> ...` for additional chunks), and dispatch the subagent with a tiny inline `task` like `"Read /tmp/<ticket>-<phase>.md and execute it. Output in your standard format."` This applies to any tool with a long string parameter (`write` `content`, `edit` `oldText`/`newText`).
- Project-local agents (`.pi/agents/*.md`) require `agentScope: "both"` or `"project"`. Default scope is `"user"` only.
- Each subagent invocation starts a fresh isolated session — do not assume the subagent can see anything from the parent's context except what's in the `task` string.

## pi agent files are symlinks to the npm package, and must point at localdev inference profiles

### Problem
- The default `~/.pi/agent/agents/*.md` files are symlinks into `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent/agents/`.
- A `pi update` overwrites those files, replacing your model IDs with the package defaults (e.g., `claude-sonnet-4-5`).
- Anthropic-API-style IDs without a Bedrock prefix make pi try the Anthropic API, which fails with `No API key found for anthropic` because this environment is Bedrock-only (`CLAUDE_CODE_USE_BEDROCK=1`).
- Even when the IDs are valid Bedrock cross-region inference profiles (e.g., `us.anthropic.claude-opus-4-8`), they bypass the `jf-localdev-*` APPLICATION inference profiles, so spend isn't tagged for cost attribution. Per `~/MODEL_ROUTING.md`, all agent traffic must go through Bedrock inference profiles — specifically the localdev ones for this user.
- Symptom: the planner/reviewer keep working through the session (configured before the update), then a worker dispatch fails immediately with the API-key error, OR everything works but spend shows up unattributed.

### How to avoid
- Replace the symlinks with real files: `cd ~/.pi/agent/agents && for f in *.md; do c=$(cat "$f"); rm "$f"; echo "$c" > "$f"; done`
- Set each agent's `model:` to the **full ARN of a `jf-localdev-*` APPLICATION inference profile**, not a raw foundation model ID and not a system-defined cross-region profile like `us.anthropic.*`. Per `~/MODEL_ROUTING.md` (planner/reviewer = Opus, worker = Sonnet, scout = Haiku). As of 2026-06-08, account `686150682967`, region `us-east-1`:
  - planner / reviewer → `arn:aws:bedrock:us-east-1:686150682967:application-inference-profile/efw9phu18v5o` (`jf-localdev-claude-48-opus-global-v1-profile`)
  - worker → `arn:aws:bedrock:us-east-1:686150682967:application-inference-profile/e04yx6lzibdz` (`jf-localdev-claude-46-sonnet-global-v1-profile`)
  - scout → `arn:aws:bedrock:us-east-1:686150682967:application-inference-profile/vgz4zbsrb75u` (`jf-localdev-claude-45-haiku-v1-profile`)
- Application inference profile ARNs don't contain the model name, so pi can't auto-detect that the underlying model supports prompt caching. **`AWS_BEDROCK_FORCE_CACHE=1` must be set in the shell** for caching to work — without it, every turn re-pays full input tokens. Already exported in `~/.zshrc`; verify with `echo $AWS_BEDROCK_FORCE_CACHE` before launching pi.
- The parent pi process is launched separately from subagents. Use the `newpi` alias in `~/.zshrc` (also pointed at a `jf-localdev-*` opus profile) to launch the top-level pi against localdev.
- After every `pi update`, re-verify with:
  - `ls -la ~/.pi/agent/agents/` — confirm files are not symlinks
  - `grep '^model:' ~/.pi/agent/agents/*.md` — confirm every line is a `jf-localdev-*` ARN
  - `aws bedrock list-inference-profiles --type-equals APPLICATION --output json | python3 -c "import json,sys; [print(p['inferenceProfileId'], p['inferenceProfileName']) for p in json.load(sys.stdin)['inferenceProfileSummaries'] if 'localdev' in p['inferenceProfileName']]"` — confirm the IDs you reference still exist and are ACTIVE
- When `~/MODEL_ROUTING.md` calls for a newer model tier (e.g., Opus 4.9 ships), find or request a matching `jf-localdev-*` profile and update both these agent files **and** the `newpi` alias in `~/.zshrc`.

## Long-running subagents look like hangs

### Problem
- Opus-backed planner and reviewer agents commonly take 2–4 minutes (sometimes longer for complex tasks with large input context).
- During that window there is no progress indicator in the parent session — it looks identical to a real hang.
- If the user sends a new message, it interrupts the in-flight subagent and the toolResult is never recorded.
- The orchestrating agent must NOT fabricate an error message (e.g., "No result provided") to explain the gap. It must report the truth: the subagent was still running when interrupted.

### How to avoid
- Before assuming a hang, wait at least 3–4 minutes for Opus subagents.
- To verify whether a subagent is actually stuck, inspect the active session log:
  `~/.pi/agent/sessions/<cwd-slug>/<latest>.jsonl` — find the `toolCall` for `subagent` and check whether a matching `toolResult` (same `toolCallId`) exists. No matching result = still running, not hung.
- Also check `ps aux | grep -iE "pi-coding|claude|bedrock"` for active processes.
- When reporting an interruption to the user, state exactly what happened (e.g., "the planner had been running for 104s with no result when you sent the new message") rather than inventing a returned error.
- For very long planning tasks, consider splitting into a `scout` pass + a shorter `planner` pass so each call completes faster and progress is visible.

## Verify the Jira ticket before starting work

### Problem
- A user-supplied ticket ID can be a typo, autocomplete miss, or out-of-date reference. Starting work on the wrong ticket wastes a planning cycle and confuses the worktree/PR naming.
- Example (2026-06-02): user said "JFR-4585" while describing deploy-hardening work; the actual JFR-4585 was about catalog grants. Caught only when `jira issue view` showed a mismatched title before the worktree was created.

### How to avoid
- Always run `jira issue view <TICKET-ID> --plain` (per `~/.pi/agent/skills/jira/SKILL.md`) before creating a branch or worktree, even if the user provided the ID confidently.
- If the ticket title doesn't match the conversational description, stop and ask the user to confirm the ID before proceeding.
