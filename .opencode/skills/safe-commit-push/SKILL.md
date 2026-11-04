---
name: safe-commit-push
description: Review, commit, synchronize with origin/main, and safely push the current Git branch.
---

# Safe commit and push

Follow these steps in order. Stop on any failed command, ambiguity, unsafe state, failed relevant check, or conflict. Report completed and skipped steps; ask for guidance where needed. Do not run destructive recovery commands.

## 1. Inspect

- Confirm this is a Git worktree (`git rev-parse --show-toplevel`), identify the active branch (`git symbolic-ref --short HEAD`), and inspect `git remote -v`, `git status`, `git status --porcelain=v1`, `git diff`, and `git diff --cached`. Inspect untracked file contents before including them. Stop on detached HEAD, unresolved conflicts, or an ongoing merge, rebase, cherry-pick, revert, or other unfinished operation. Check Git's worktree-specific paths for operation state with `git rev-parse --git-path`.
- Identify the current task from the user's request and conversation. If its scope or intended destination is unclear, ask. Inspect staged changes as well as unstaged changes; never include unrelated staged content. Do not alter the user's index to remove unrelated changes: stop and ask.
- Verify `origin` points to the intended repository. Determine the current branch's configured upstream and actual push destination, including push URLs and refspecs. If a destination differs from the intended repository or branch, or cannot be verified, stop and ask. Never print credentials embedded in remote URLs.

## 2. Fetch and review

- Run `git fetch origin main`; verify success. Confirm `origin/main` exists and equals the fetched main commit in `FETCH_HEAD`. If the fetch configuration did not update `origin/main`, stop rather than using a stale reference. Fetching alone does not update the current branch.
- Review actual changes, including new files. Include only task-related files. Exclude generated artifacts, secrets, credentials, and local environment files. If files or hunks cannot be separated safely, stop and ask. Do not stage a whole directory indiscriminately. If excluded changes would leave the working tree or index dirty, stop and ask; do not stash or discard them.
- Run relevant available project checks. Report actual outcomes, including unavailable or skipped checks. Stop if a relevant check fails; never claim an unrun check passed.

## 3. Commit

- Stage only reviewed task-related paths or hunks, preserving the user's work. Verify `git diff --cached` contains exactly the intended changes and no secrets. Stop if the staged diff is empty. Create one commit with a short, specific Conventional Commit message, such as `fix: validate login response`. Do not amend.
- Use the user's configured Git identity. Do not add AI names, attribution, or `Co-authored-by` trailers to commit messages. Do not change or impersonate the configured identity.
- Confirm `git status --porcelain=v1` is empty, including untracked files. Otherwise stop; do not stash, clean, or discard anything.

## 4. Synchronize

- Compare `HEAD` and `origin/main` using ancestry checks and `git rev-list --left-right --count HEAD...origin/main`. Fetching did not integrate remote changes.
- On `main`, never rebase or rewrite history. If `HEAD` is an ancestor of `origin/main`, fast-forward only (`git merge --ff-only origin/main`). If both sides have unique commits, stop and report divergence. A new commit on an out-of-date main normally creates divergence; stop rather than rebasing it.
- On a feature branch, if `origin/main` is not already an ancestor of `HEAD`, inspect the branch's upstream and history. Rebase only if you can establish that none of the commits to be rewritten have been published or shared. If the branch is shared, unexpectedly diverged, or publication or strategy is unclear, stop and ask for guidance. Do not merge branches without authorization. An authorized merge must preserve both histories; never auto-resolve uncertain conflicts.
- Stop and report any merge or rebase conflict, leaving the operation and files intact. If integration changes committed code, rerun relevant checks and stop on failure. Confirm the worktree is clean and `origin/main` is an ancestor of `HEAD` before pushing.

## 5. Push

- Verify the intended remote, push URL, and exact destination branch again. Check remote branch state and stop if it has advanced or diverged unexpectedly; do not overwrite remote work. Push only the current branch using an explicit remote and refspec, e.g. `git push origin HEAD:refs/heads/<verified-branch>`.
- Never push to `main` without explicit user approval. For a feature branch without an upstream, configure tracking only after verifying the intended remote branch and repository; use `git push -u` with the verified explicit refspec. If no intended destination can be established, ask.
- Never force push, including `--force-with-lease`. If rejected, stop and explain; do not retry destructively. Never delete branches, create pull requests, run `git reset --hard` or `git clean -fd`, automatically stash or discard changes, or modify unrelated files.

## Report

Report current branch, remote, fetch result, commit hash and message, synchronization result, checks, push result, and blockers. Distinguish success, failure, and skipped steps; do not imply an unexecuted operation succeeded.
