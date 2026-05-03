# Dummy App

This Rails app exists to validate Recording Studio Trashable inside a realistic host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio and addon events
- Workspace root recording plus project, folder, and page examples
- Explicit trashable opt-in on `Page` only
- Mounted workspace and project scoped trash bins
- Restore, purge, and retention settings flows through the addon engine
- Sidebar showcase pages for Setup, Configuration, Adding to a recordable, and Methods

## Quick Start

```bash
bundle install
bin/rails db:setup
bin/dev
```

Then sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - dummy app demo home page
- `/recording_studio` - mounted Recording Studio engine
- `/recording_studio_trashable` - addon overview page
- `/recording_studio_trashable/recordings/:recording_id/trash_bin` - subtree trash bin UI
- `/showcase/setup` - dummy app documentation pages
