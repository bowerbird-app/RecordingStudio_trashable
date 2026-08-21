# RecordingStudio 4.2 Update Summary

## Current branch summary

This branch wraps Trashable enablement around RecordingStudio 4.2's `include_for` factory.

### Dependency changes

- `recording_studio` is pinned to tag `v4.2.0` in the root and dummy app Gemfiles.
- The gemspec now requires `recording_studio ~> 4.2`.
- The gem version is `0.4.0`.

### Enablement

- Canonical host verb remains `include RecordingStudio::Capabilities::Trashable.to(**opts)`.
- `.to` is a thin wrapper around `RecordingStudio::Capabilities.include_for(:trashable, **options)`.
- Option validation stays in this gem. `register_capability` still runs at boot and is not inside `.to`.
- Installing the gem does not enable trash. Dummy `Page` stays the only opt-in recordable.

### Release classification

This is a minor feature release. Host apps still on RecordingStudio `4.1.x` should stay on Trashable `0.3.x`.

### Verification notes

Do not rely on this file as a historical test log. Before merge, rerun and record the current results for:

- `bundle exec rubocop`
- `bundle exec rake app:test`
- `bundle exec rake db:migrate RAILS_ENV=test` from `test/dummy`
- `bundle exec rails tailwindcss:build` from `test/dummy`
