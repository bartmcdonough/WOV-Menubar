# Codex Editing Rules

- Run `git status` before making any file change.
- If the working tree is not clean, assume patch context may be stale and inspect relevant files before editing.
- Prefer small, localized edits over large patches or broad multi-file changes.
- Re-read a file immediately before editing it again in the same session.
- Do not batch multiple risky edits without committing in between.
- After every successful, meaningful change, run:
  - `git add .`
  - `git commit -m "codex: <short description>"`
- Use `apply_patch` only for small, clean edits against freshly read context.
- Prefer direct file editing instead of `apply_patch` when the file has already been modified in the session.
- Prefer direct file editing instead of `apply_patch` when the change is large or spans many sections.
- Prefer direct file editing instead of `apply_patch` when formatting or whitespace may have changed.
- Prefer direct file editing instead of `apply_patch` when any previous patch attempt on the file failed.
- If `apply_patch` fails once on a file, re-read the file and retry once with a smaller change.
- If `apply_patch` fails twice on the same file, stop using `apply_patch` for that file and modify it directly.
- After each change, run the smallest relevant verification step.
- If verification cannot run, state exactly why.
