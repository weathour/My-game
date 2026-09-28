# Legacy Git history archive

This directory is a historical boundary, not a gameplay module.

The old implementations are already preserved losslessly in the repository's
Git object database. This directory groups the history into a single place by
providing:

- `GIT_HISTORY_INDEX.md`: every commit reachable from the repository refs,
  ordered newest first.
- `ARCHIVE_MANIFEST.json`: the source revision, refs, and archive rules used
  to generate the index.

The archive does not duplicate every historical checkout. Duplicating all
revisions would add a large second copy of the repository while providing no
additional recovery capability. Any historical file can be recovered exactly
with Git, for example:

```text
git show <commit>:<path>
git archive <commit> -- <path>
```

The `.gdignore` file keeps Godot from importing this directory. Nothing in
this directory is loaded by the game. The archive is also excluded from
ordinary code and gameplay searches by the repository `AGENTS.md` and the
root `.rgignore` file.

The index is generated from the committed `HEAD` and repository refs. Current
uncommitted working-tree changes are deliberately not included.
