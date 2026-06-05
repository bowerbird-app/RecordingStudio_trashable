# RecordingStudio 3.0 Update Summary

## Current branch summary

This branch updates `recording_studio_trashable` for RecordingStudio 3.0 compatibility.

### Dependency changes

- `recording_studio` is pinned to tag `recording_studio/v3.0.0` in the root and dummy app Gemfiles.
- Both lockfiles resolve RecordingStudio to revision `7667687155bf05ab41b66dfccae330dc3834c39c`.
- Both lockfiles resolve FlatPack tag `v0.1.33` to commit `bb6155be46d90db4932627d632bc26849538ca10`.
- The gemspec now requires `recording_studio ~> 3.0`.

### Compatibility changes

- Host recordables now use RecordingStudio 3.x `recording_studio_recordable(...)` declarations.
- The removed core `RecordingStudio::Services::AccessCheck` fallback is no longer used; applications should configure a custom resolver, use `RecordingStudioAccessible`, or keep the default deny behavior.
- Trash bins use `trash_root` tracking so only explicitly trashed subtree roots are listed.
- Retention purges skip a parent until every trashed descendant in that subtree is also retention-due.

### Release classification

This is a breaking change because it drops compatibility with pre-3.0 RecordingStudio APIs. The commit and release metadata should use a Conventional Commits breaking-change signal (`feat!` or a `BREAKING CHANGE:` footer), which should classify the automatic release as major.

### Verification notes

Do not rely on this file as a historical test log. Before merge, rerun and record the current results for:

- `bundle exec rubocop`
- `bundle exec rake app:test`
- `bundle exec rake db:migrate RAILS_ENV=test` from `test/dummy`
- `bundle exec rails tailwindcss:build` from `test/dummy`
