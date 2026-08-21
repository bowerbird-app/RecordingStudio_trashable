# Migration Notes - Private Gems to Public Gems

## Changes Made

1. ✅ Removed repository access entries from `.devcontainer/devcontainer.json`
2. ✅ Updated documentation in `CODESPACES.md` and `PRIVATE_GEMS.md`
3. ✅ Updated copilot instructions to reference local docs
4. ✅ Replaced `makeup_artist` with `flat_pack` in `test/dummy/Gemfile`

## Next Steps (Requires Ruby 3.3.0+)

The following steps need to be completed in an environment with Ruby 3.3.0 or higher:

1. **Update Gemfile.lock**: Run `bundle install` in the test/dummy directory to update the lockfile
   ```bash
   cd test/dummy
   bundle install
   ```

2. **Run FlatPack installer**: After bundle install, run the FlatPack installation generator
   ```bash
   cd test/dummy
   rails generate flat_pack:install
   ```

3. **Update views**: Replace any `makeup_artist` component references with `flat_pack` components
   - Search for: `MakeupArtist::`, `makeup_artist/`
   - Replace with equivalent FlatPack components

4. **Test the application**: Start the dummy app and verify all UI components work
   ```bash
   cd test/dummy
   bin/dev
   ```

5. **Run tests**: Execute the test suite
   ```bash
   bundle exec rake test
   ```

## Component Migration Guide

FlatPack is the successor to MakeupArtist with similar components:

- Both use ViewComponent architecture
- Both integrate with Tailwind CSS
- Component names and APIs may differ slightly

See: https://github.com/bowerbird-app/flatpack for component documentation

## RecordingStudio 4 Compatibility Notes

- `recording_studio_trashable` depends on `recording_studio ~> 4.1`; app Gemfiles should pin the RecordingStudio repository to tag `v4.1.0` when testing this update.
- Every configured host recordable must declare `recording_studio_recordable(...)`. In the dummy app, `Workspace` is the only root; `Project`, `Folder`, and `Page` are child recordables with explicit `allowed_parent_types` matching the demo tree, including nested Page recordings used by trash-root examples.
- Trashable registers only the `trashable` capability source (`recording_studio_trashable`). It does not declare capability-owned `child_recordables`.
- RecordingStudio core does not provide the old `RecordingStudio::Services::AccessCheck` fallback. Configure a custom resolver, use `RecordingStudioAccessible`, or leave the default deny behavior in place.
- Host apps should install RecordingStudio 4 harden / unique-root indexes (`rails generate recording_studio:migrations` then `db:migrate`) and resolve duplicate root recordings before the unique index is created.
- Trashable owns its `trashed_at`, `trash_root`, and retention settings schema. Purge permanently removes recording rows after logging the explicit `purged` action, so host apps should document any external audit-history retention policy they require before scheduled purges run.
