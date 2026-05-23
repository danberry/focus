---
name: pr
description: >
  Creates and merges a pull request for the Focus iOS app. Use this skill whenever
  the user asks to "open a PR", "create a pull request", "submit a PR", "ship this",
  "merge this branch", "get this merged", or any similar request to propose or land
  a change — even if they phrase it casually. The skill handles the full lifecycle:
  local build verification, PR creation targeting develop, CI check monitoring, and
  merge with branch cleanup. Use it whenever changes are ready to ship, even if the
  user only says "can you make the PR?" or "ship it".
---

# create-and-merge-pr

Full PR lifecycle for the Focus iOS app: build → push → create PR → wait for CI → merge.

## Prerequisites

- `gh` CLI is at `/opt/homebrew/bin/gh` — always use the full path.
- The current branch must not be `develop` or `main`. Verify with `git branch --show-current`.
- All file edits must be committed before starting.

## Step 1 — Build verification

Run xcodebuild from the worktree root (or project root if not in a worktree):

```bash
xcodebuild \
  -scheme Focus \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -project <path-to>/Focus.xcodeproj \
  build 2>&1 | tail -5
```

Look for `** BUILD SUCCEEDED **`. If the build fails:
- Read the compiler errors carefully.
- Fix the issues, re-stage and commit.
- Re-run the build before proceeding.

Do not move to Step 2 until the build is clean. This prevents shipping broken code — a real incident (PR #348) showed this catches errors before they reach reviewers.

## Step 2 — Push branch

Push the current branch to origin if it isn't already:

```bash
git push -u origin HEAD
```

If the push is rejected (non-fast-forward), investigate before force-pushing. Never force-push `develop`.

## Step 3 — Create the PR

```bash
/opt/homebrew/bin/gh pr create \
  --base develop \
  --title "<concise title under 70 chars>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet 1>
- <bullet 2>

## Test plan
- [ ] Build succeeded locally
- [ ] <manual test step specific to this change>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Title guidance**: imperative form, under 70 chars. Match the style of recent commits on `develop` (check with `git log develop --oneline -5`).

**Body guidance**: keep the Summary tight — what changed and why. The Test plan should be concrete and specific to what was changed, not boilerplate.

After creation, print the PR URL so the user can see it.

## Step 4 — Wait for CI checks

Once the PR is open, poll until all checks pass or one fails:

```bash
/opt/homebrew/bin/gh pr checks --watch
```

This streams check status as they update. Wait for all checks to reach a terminal state:
- **All green** → proceed to Step 5.
- **Any failure** → stop, surface the failure details to the user, and ask how they'd like to proceed (fix and re-push, or skip CI).

If there are no checks configured, skip this step and proceed directly to merge.

## Step 5 — Merge

Merge with squash and delete the remote branch:

```bash
/opt/homebrew/bin/gh pr merge --squash --delete-branch
```

After merge completes:
1. Confirm success by printing the merge commit reference.
2. Let the user know the branch has been deleted on origin.
3. Optionally remind them to `git pull develop` locally if they need the merged commit.

## Failure handling

| Situation | Action |
|-----------|--------|
| Build fails | Fix errors, commit, re-run build before any PR work |
| Push rejected | Investigate; do not force-push without user confirmation |
| CI check fails | Surface the failure; do not merge; ask the user |
| PR already exists | Use `gh pr view` to find it and skip creation |
| Merge conflicts | Surface them; do not attempt auto-resolution without user review |

## Notes

- Never skip the build step — it exists because a broken build once shipped to reviewers.
- Always use `/opt/homebrew/bin/gh`, not a bare `gh` — the PATH in the Bash tool environment may not include Homebrew.
- The worktree path convention is `.claude/worktrees/<name>/` — use that path when referencing the `.xcodeproj`.
