class ShowcaseController < ApplicationController
  PAGES = {
    "overview" => {
      title: "Overview",
      subtitle: "What the Trashable addon changes in Recording Studio and what it leaves alone.",
      sections: [
        {
          title: "Recording Studio specific trash",
          anchor_id: "recording-studio-specific-trash",
          body: "Trashable is built specifically for Recording Studio. It extends Recording Studio's recording lifecycle, mounted UI, and retention flow rather than introducing a generic soft-delete system for unrelated app models."
        },
        {
          title: "Timestamp based trash state",
          anchor_id: "timestamp-based-trash-state",
          body: "The addon adds a nullable trashed_at timestamp and a trash_root boolean to recording_studio_recordings. A recording is active when trashed_at is nil and considered trashed when that timestamp is present. trash_root marks which trashed recordings appear in the trash bin as explicit restore points."
        },
        {
          title: "Trash and restore behavior",
          anchor_id: "trash-and-restore-behavior",
          body: "Trashing a recording logs a Recording Studio event, sets trashed_at to the current time, and marks the directly trashed node as the trash_root. Restoring logs a restore event and clears trashed_at back to nil for the selected root plus cascade-trashed descendants, while nested explicit trash roots stay trashed."
        },
        {
          title: "Subtree lifecycle",
          anchor_id: "subtree-lifecycle",
          body: "Trash, restore, and purge operate on the targeted recording subtree so parents and descendants stay in sync through the full lifecycle. Restore walks the subtree until it reaches another trash_root branch, which remains trashed until restored directly."
        },
        {
          title: "What is not trashed",
          anchor_id: "what-is-not-trashed",
          body: "Trash applies to Recording Studio recording rows. It does not soft-delete the underlying recordable data row, and it does not trash Recording Studio event rows. Instead, trash, restore, and purge actions create events so the lifecycle stays auditable."
        }
      ]
    },
    "setup" => {
      title: "Setup",
      subtitle: "Install the addon, run the generators, migrate the schema, and wire up retention purging.",
      sections: [
        {
          title: "Install the gem",
          anchor_id: "install-the-gem",
          subtitle: "Add the addon to the host app and load its initializer.",
          body: "Start by adding recording_studio_trashable alongside recording_studio in the host application's Gemfile. The install generator will create config/initializers/recording_studio_trashable.rb and mount the engine for you, so most apps can use the default path unless they need a custom mount point.",
          code_title: "Gemfile and optional manual mount",
          code_language: :ruby,
          code: <<~RUBY
            gem "recording_studio"
            gem "recording_studio_trashable"

            # Only add this route yourself when you skip the install generator.
            mount RecordingStudioTrashable::Engine, at: "/recording_studio_trashable"
          RUBY
        },
        {
          title: "Run the generators",
          anchor_id: "run-the-generators",
          subtitle: "Use the install generator first, then copy the addon migrations into the host app.",
          body: "The install generator mounts the engine, writes the Trashable initializer, and adds Tailwind source paths when the host app already has Tailwind configured. After that, run the migrations generator so the host app gets the compatibility migrations for trashed_at, trash_root, and the retention settings table.",
          code_title: "Install and migration generators",
          code_language: :bash,
          code: <<~BASH
            bundle install
            bin/rails generate recording_studio_trashable:install
            bin/rails generate recording_studio_trashable:migrations
            bin/rails db:migrate
          BASH
        },
        {
          title: "Apply the database changes",
          anchor_id: "apply-the-database-changes",
          subtitle: "Trashable updates Recording Studio's recordings table and creates its own retention settings table.",
          body: "The generated migrations touch two tables. recording_studio_recordings gets a nullable trashed_at datetime, a non-null trash_root boolean, and supporting indexes so active, root-only trash, and restore queries stay fast. recording_studio_trashable_retention_settings is a new addon-owned table keyed by recording_id with one retention override per scope root.",
          code_title: "Schema changes created by the addon",
          code_language: :ruby,
          code: <<~RUBY
            add_column :recording_studio_recordings, :trashed_at, :datetime
            add_index :recording_studio_recordings, :trashed_at
            add_column :recording_studio_recordings, :trash_root, :boolean, default: false, null: false
            add_index :recording_studio_recordings, [:trashed_at, :trash_root], name: "idx_rs_recordings_trashed_at_trash_root"

            create_table :recording_studio_trashable_retention_settings, id: :uuid do |t|
              t.references :recording,
                           null: false,
                           type: :uuid,
                           foreign_key: { to_table: :recording_studio_recordings },
                           index: { unique: true, name: "idx_rs_trashable_retention_on_recording" }
              t.integer :purge_after_days
              t.timestamps
            end
          RUBY
        },
        {
          title: "Schedule background purges",
          anchor_id: "schedule-background-purges",
          subtitle: "Run the retention sweep from a job queue or a scheduler once the app has a purge actor configured.",
          body: "Retention purging can be triggered directly through RecordingStudioTrashable::RetentionPurgeJob or through the bundled rake task. If the host app uses RecordingStudioAccessible, configure retention_purge_actor_resolver so scheduled work runs as a real actor that is allowed to purge. Use the rake task when your scheduler prefers shell commands, and use the job entry point when your app already has Sidekiq, Solid Queue, or another Active Job backend in place.",
          code_title: "Background job and scheduler entry points",
          code_language: :ruby,
          code: <<~RUBY
            RecordingStudioTrashable.configure do |config|
              config.retention_purge_actor_resolver = -> { User.find_by!(email: "system@example.com") }
            end

            RecordingStudioTrashable::RetentionPurgeJob.perform_later
          RUBY
        }
      ]
    },
    "configuration" => {
      title: "Configuration",
      code_title: "config/initializers/recording_studio_trashable.rb",
      code_language: :ruby,
      code: <<~RUBY
        RecordingStudioTrashable.configure do |config|
          # Enables Accessible permission checks so trash actions respect the host app's role rules.
          config.use_recording_studio_accessible = true

          # Purges trashed recordings after 30 days when no record-specific retention setting overrides it.
          config.default_purge_after_days = 30

          # Lets authorized users manage retention preferences from the addon UI.
          config.allow_user_retention_settings = true

          # Maps each trash lifecycle action to the minimum Accessible role required to perform it.
          config.authorization_roles = {
            trash: :edit,
            restore: :edit,
            purge: :admin,
            manage_retention: :admin
          }

          # Resolves the acting user recorded in trash, restore, and purge audit metadata.
          config.current_actor_resolver = ->(controller) { controller.current_user }

          # Resolves the impersonating user when an admin is acting on behalf of someone else.
          config.current_impersonator_resolver = ->(controller) { controller.true_user }
        end
      RUBY
    },
    "adding-to-a-recordable" => {
      title: "Adding to a recordable",
      code_title: "Adding trashable to a recordable type",
      code_language: :ruby,
      code: <<~RUBY
        class Page < ApplicationRecord
          include RecordingStudio::Capabilities::Trashable.to
        end

        page_recording.recording_studio_trashable_trash!(
          actor: current_user,
          impersonator: Current.impersonator,
          metadata: { source: "bulk-cleanup" }
        )

        page_recording.recording_studio_trashable_restore!(
          actor: current_user,
          metadata: { source: "undo" }
        )

        page_recording.recording_studio_trashable_purge!(
          actor: current_user,
          metadata: { source: "retention" }
        )
      RUBY
    },
    "trash-cans" => {
      title: "Trash cans",
      subtitle: "Trash-bin pages are scoped by the parent recording you pass in.",
      body: "A trash can shows the trash roots beneath a specific recording. In most apps that parent will be the root workspace recording so the trash can covers everything below it, but it can just as easily be a project recording when you want a smaller subtree. Cascade-trashed descendants stay hidden until their nearest explicit trash root is restored or purged. This gem already provides the trash-can view and controller flow, so integrating it is usually just a matter of linking to the mounted trash-bin route with the parent recording that defines the scope.",
      code_title: "Link to a scoped trash can",
      code_language: :erb,
      code: <<~ERB
        <%= link_to "Project trash can",
                    recording_studio_trashable.recording_trash_bin_path(@project_recording),
                    class: "text-sm font-medium underline" %>

        <%= link_to "Workspace trash can",
                    recording_studio_trashable.recording_trash_bin_path(@root_recording),
                    class: "text-sm font-medium underline" %>
      ERB
    },
    "trash-roots" => {
      title: "Trash roots",
      subtitle: "Explicit restore points keep nested trash operations from undoing each other.",
      sections: [
        {
          title: "How trash roots work",
          anchor_id: "how-trash-roots-work",
          body: "When a user explicitly trashes a recording, that recording becomes the trash_root for its subtree. Descendants that were only dragged into the trash by cascade get trashed_at timestamps too, but they stay hidden behind that nearest root instead of appearing as separate restore targets.\n\nWe use trash roots so restore stays predictable. When you restore a parent subtree, the walk stops before a nested recording that was explicitly trashed later. That prevents a broad restore from accidentally reviving children that a user intentionally trashed on their own timeline."
        },
        {
          title: "Example recording tree",
          anchor_id: "example-recording-tree",
          subtitle: "Only explicitly trashed nodes are marked as roots in the trash bin.",
          code_title: "Dot list with trash roots marked",
          code_language: :text,
          code: <<~TEXT
            . Workspace
              . Project Alpha
                . Page Briefing
                . Folder Archive (trash root)
                  . Page Session Notes
                  . Page Raw Takes
                . Folder Deliverables
                  . Page Release Checklist (trash root)
                    . Page QA Notes
          TEXT
        },
        {
          title: "Why the boundary matters",
          anchor_id: "why-the-boundary-matters",
          body: "In that tree, restoring Workspace or Project Alpha should not automatically restore Folder Archive or Page Release Checklist if those branches were explicitly trashed as their own actions. The restore logic therefore clears cascade-trashed descendants until it reaches another trash_root branch, which remains in the trash until restored directly."
        }
      ]
    },
    "retention" => {
      title: "Retention",
      subtitle: "How the default retention window, optional user overrides, and purge sweep fit together.",
      sections: [
        {
          title: "App-level retention",
          anchor_id: "app-level-retention",
          subtitle: "When should trash be permanantly deleted?",
          code_title: "Set the application default",
          code_language: :ruby,
          code: <<~RUBY
            RecordingStudioTrashable.configure do |config|
              config.default_purge_after_days = 30
            end
          RUBY
        },
        {
          title: "Recordable level retention",
          anchor_id: "recordable-level-retention",
          subtitle: "Set different retention periods for different recordables",
          code_title: "Set retention on a recordable",
          code_language: :ruby,
          code: <<~RUBY

            class Project < ApplicationRecord
              include RecordingStudio::Capabilities::Trashable.to(purge_after_days: 14)
            end
          RUBY
        },
        {
          title: "Allow users to set retention periods",
          anchor_id: "turn-on-retention-settings-for-users",
          subtitle: "Enable the mounted settings page and decide who can edit it.",
          code_title: "Allow per-scope retention settings",
          code_language: :ruby,
          code: <<~RUBY
            RecordingStudioTrashable.configure do |config|
              config.allow_user_retention_settings = true
              config.authorization_roles = {
                trash: :edit,
                restore: :edit,
                purge: :admin,
                settings: :admin
              }
            end
          RUBY
        },
        {
          title: "How the purge background task works",
          anchor_id: "how-the-purge-background-task-works",
          subtitle: "The rake task runs the retention job, which evaluates each scope and purges recordings that are due.",
          body: "Running the purge task calls RecordingStudioTrashable::RetentionPurgeJob, which sweeps every root scope recording by default or the specific scope IDs you pass in. For each scope, the purger asks RetentionPolicy whether a trashed recording is due as of the current time, then purges the deepest descendants first so parent rows are not removed before their trashed children. SOURCE is copied into the audit metadata, and AS_OF lets you run a deterministic backfill or dry-run style check against a fixed timestamp.",
          code_title: "Run the retention purge sweep",
          code_language: :bash,
          code: <<~BASH
            bundle exec rake recording_studio_trashable:purge_due

            bundle exec rake recording_studio_trashable:purge_due \
              SCOPE_RECORDING_IDS=123,456 \
              AS_OF=2026-05-01T00:00:00Z \
              SOURCE=nightly-retention
          BASH
        }
      ]
    },
    "responses" => {
      title: "Responses",
      subtitle: "Lifecycle actions redirect back by default and only switch to JSON when async is requested.",
      sections: [
        {
          title: "Reload existing page",
          subtitle: "Default behaviour",
          body: "After a recording is trashed, restored or purged the current page is refreshed and a flash message is returned."
        },
        {
          title: "Async",
          subtitle: "Opt-in JSON responses",
          body: "Use async when the page should stay in place and handle the lifecycle result in JavaScript. Async requests skip the redirect and return a JSON payload with either a notice or an alert."
        }
      ],
      code_title: "Return to the current page after trashing",
      code_language: :erb,
      code: <<~ERB
        <%= form_with url: recording_studio_trashable.trash_recording_path(recording),
                      method: :patch,
                      data: { turbo: false } do %>
          <%= render FlatPack::Button::Component.new(text: "Trash", style: :primary, type: "submit") %>
        <% end %>
      ERB
    },
    "methods" => {
      title: "Methods",
      subtitle: "Methods and scopes added by the trashable capability",
      methods: [
        {
          title: "Trash a recording",
          anchor_id: "trash-a-recording",
          name: "recording_studio_trashable_trash!(actor: nil, impersonator: nil, metadata: {})",
          code_title: "Usage",
          code: <<~RUBY
            # Soft delete the recording, cascade to descendants, and record who performed the action.
            recording.recording_studio_trashable_trash!(
              actor: current_user,
              metadata: { source: "workspace-cleanup" }
            )
          RUBY
        },
        {
          title: "Restore a recording",
          anchor_id: "restore-a-recording",
          name: "recording_studio_trashable_restore!(actor: nil, impersonator: nil, metadata: {})",
          code_title: "Usage",
          code: <<~RUBY
            # Bring a trashed recording subtree back and log who restored it.
            recording.recording_studio_trashable_restore!(
              actor: current_user,
              metadata: { source: "support-request" }
            )
          RUBY
        },
        {
          title: "Purge a recording",
          anchor_id: "purge-a-recording",
          name: "recording_studio_trashable_purge!(actor: nil, impersonator: nil, metadata: {})",
          code_title: "Usage",
          code: <<~RUBY
            # Permanently remove a trashed recording subtree after retention and authorization checks pass.
            recording.recording_studio_trashable_purge!(
              actor: current_user,
              metadata: { source: "retention-purge" }
            )
          RUBY
        },
        {
          title: "Filter recordings by trash state",
          anchor_id: "filter-recordings-by-trash-state",
          name: "recording_studio_trashable_filter(:active | :trashed | :all)",
          code_title: "Usage",
          code: <<~RUBY
            # Switch between active, trashed, or all recordings without changing the rest of the query.
            # The named scopes remain available when you want the explicit form.
            project.recordings.recording_studio_trashable_filter(:trashed)
          RUBY
        },
        {
          title: "Query active recordings",
          anchor_id: "query-active-recordings",
          name: "recording_studio_trashable_active",
          code_title: "Usage",
          code: <<~RUBY
            # Return only active recordings for this recordable.
            # Trashed rows stay out of the relation by default.
            project.recordings.recording_studio_trashable_active
          RUBY
        },
        {
          title: "Query trashed recordings",
          anchor_id: "query-trashed-recordings",
          name: "recording_studio_trashable_trashed",
          code_title: "Usage",
          code: <<~RUBY
            # Return only recordings that are currently in the trash.
            # Use this when auditing every trashed descendant in a subtree.
            project.recordings.recording_studio_trashable_trashed
          RUBY
        },
        {
          title: "Query active and trashed recordings",
          anchor_id: "query-active-and-trashed-recordings",
          name: "recording_studio_trashable_including_trashed",
          code_title: "Usage",
          code: <<~RUBY
            # Remove the default trash filter so both active and trashed rows are returned.
            # Use this when you need a complete view of the recordable's recordings.
            project.recordings.recording_studio_trashable_including_trashed
          RUBY
        },
        {
          title: "Build a trash-bin listing",
          anchor_id: "build-a-trash-bin-listing",
          name: "recording_studio_trashable_trash_bin",
          code_title: "Usage",
          code: <<~RUBY
            # Fetch explicit trash roots in the order expected by trash-bin screens.
            # Cascade-trashed descendants stay hidden behind their nearest trash root.
            project.recordings.recording_studio_trashable_trash_bin
          RUBY
        },
        {
          title: "Query trash roots",
          anchor_id: "query-trash-roots",
          name: "recording_studio_trashable_trash_roots",
          code_title: "Usage",
          code: <<~RUBY
            # Return only explicitly trashed recordings that anchor a trashed subtree.
            # Use this to build quieter trash-bin listings or restore summaries.
            project.recordings.recording_studio_trashable_trash_roots
          RUBY
        }
      ]
    }
  }.freeze

  def show
    @page = PAGES.fetch(params[:slug])
  end
end
