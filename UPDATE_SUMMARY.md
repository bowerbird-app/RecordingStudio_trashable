# RecordingStudio 4.1 Update Summary

## Current branch summary

This branch updates `recording_studio_trashable` for RecordingStudio 4.1 compatibility.

### Dependency changes

- `recording_studio` is pinned to tag `v4.1.0` in the root and dummy app Gemfiles.
- `flat_pack` is pinned to tag `v0.1.133` in the root and dummy app Gemfiles.
- The gemspec now requires `recording_studio ~> 4.1`.
- The gem version is `0.3.0` for the breaking dependency floor.

### Compatibility changes

- Host recordables still use `recording_studio_recordable(...)` declarations and opt into trash with `RecordingStudio::Capabilities::Trashable.to(...)`.
- The dummy app installs the RecordingStudio 4 harden / unique-root indexes.
- Authorization is unchanged: configure a custom resolver, use `RecordingStudioAccessible`, or keep the default deny behavior.

### Release classification

This is a breaking change because it drops compatibility with RecordingStudio 3.x. Host apps still on RecordingStudio 3 should stay on Trashable `0.2.x`.

### Verification notes

Do not rely on this file as a historical test log. Before merge, rerun and record the current results for:

- `bundle exec rubocop`
- `bundle exec rake app:test`
- `bundle exec rake db:migrate RAILS_ENV=test` from `test/dummy`
- `bundle exec rails tailwindcss:build` from `test/dummy`
