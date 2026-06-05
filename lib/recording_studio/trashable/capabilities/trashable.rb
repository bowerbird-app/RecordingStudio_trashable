# frozen_string_literal: true

module RecordingStudioTrashable
  module RecordingScopes
    FILTER_SCOPES = {
      active: :recording_studio_trashable_active,
      trashed: :recording_studio_trashable_trashed,
      all: :recording_studio_trashable_including_trashed
    }.freeze

    extend ActiveSupport::Concern

    included do
      scope :recording_studio_trashable_active, -> { unscope(where: :trashed_at).where(trashed_at: nil) }
      scope :recording_studio_trashable_trashed, -> { unscope(where: :trashed_at).where.not(trashed_at: nil) }
      scope :recording_studio_trashable_including_trashed, -> { unscope(where: :trashed_at) }
      scope :recording_studio_trashable_trash_roots, -> { recording_studio_trashable_trashed.where(trash_root: true) }
      scope :recording_studio_trashable_filter, lambda { |filter|
        filter_key = filter.to_sym
        scope_name = FILTER_SCOPES.fetch(filter_key) do
          raise ArgumentError,
                "Unknown trash filter #{filter.inspect}. Expected one of: #{FILTER_SCOPES.keys.join(', ')}"
        end

        public_send(scope_name)
      }
      scope :recording_studio_trashable_trash_bin, lambda {
        recording_studio_trashable_trash_roots.reorder(trashed_at: :desc, updated_at: :desc)
      }
    end
  end
end

module RecordingStudio
  module Trashable
    module Capabilities
      module Trashable
        def self.to(**options)
          build_capability_module(capability_options(options))
        end

        def self.build_capability_module(options)
          Module.new do
            extend ActiveSupport::Concern

            included do |base|
              RecordingStudio::Trashable::Capabilities::Trashable.apply_capability(base, options)
            end
          end
        end

        def self.apply_capability(base, options)
          RecordingStudio.enable_capability(:trashable, on: base.name)
          RecordingStudio.set_capability_options(:trashable, on: base.name, **options)
        end

        def self.capability_options(options)
          options.to_h.transform_keys(&:to_sym)
        end

        # rubocop:disable Metrics/ModuleLength, Metrics/MethodLength
        module RecordingMethods
          include RecordingStudio::Capability

          def recording_studio_trashable_trash!(actor: nil, impersonator: nil, metadata: {})
            recording_studio_trashable_assert_capability!
            recording_studio_trashable_authorize!(:trash, actor: actor)
            recording_studio_trashable_with_locked_targets do |targets|
              targets.reverse_each do |recording|
                next if recording.trashed_at.present?

                recording.log_event!(
                  action: "trashed",
                  actor: recording_studio_trashable_actor(actor),
                  impersonator: recording_studio_trashable_impersonator(impersonator),
                  metadata: recording_studio_trashable_metadata(metadata)
                )
                recording.update!(trashed_at: Time.current, trash_root: recording.id == id)
              end
            end
            reload
          end

          def recording_studio_trashable_restore!(actor: nil, impersonator: nil, metadata: {})
            recording_studio_trashable_assert_capability!
            recording_studio_trashable_authorize!(:restore, actor: actor)
            recording_studio_trashable_with_locked_targets(mode: :restore) do |targets|
              targets.each do |recording|
                next if recording.trashed_at.blank?

                recording.log_event!(
                  action: "restored",
                  actor: recording_studio_trashable_actor(actor),
                  impersonator: recording_studio_trashable_impersonator(impersonator),
                  metadata: recording_studio_trashable_metadata(metadata)
                )
                recording.update!(trashed_at: nil, trash_root: false)
              end
            end
            reload
          end

          def recording_studio_trashable_purge!(actor: nil, impersonator: nil, metadata: {})
            recording_studio_trashable_validate_purge!(actor: actor)
            recording_studio_trashable_with_locked_targets do |targets|
              targets.reverse_each do |recording|
                recording.log_event!(
                  action: "purged",
                  actor: recording_studio_trashable_actor(actor),
                  impersonator: recording_studio_trashable_impersonator(impersonator),
                  metadata: recording_studio_trashable_metadata(metadata)
                )
                recording.destroy!
              end
            end
            self
          end

          # rubocop:disable Naming/PredicateMethod
          def recording_studio_trashable_validate_purge!(actor: nil)
            recording_studio_trashable_assert_capability!
            recording_studio_trashable_authorize!(:purge, actor: actor)
            recording_studio_trashable_with_locked_targets do |targets|
              recording_studio_trashable_assert_purge_targets!(targets)
            end

            true
          end
          # rubocop:enable Naming/PredicateMethod

          private

          def recording_studio_trashable_assert_capability!
            assert_capability!(:trashable)
          end

          def recording_studio_trashable_authorize!(action, actor: nil)
            resolved_actor = recording_studio_trashable_actor(actor)
            return if RecordingStudioTrashable.authorized?(action: action, actor: resolved_actor, recording: self)

            raise ArgumentError, "Not authorized to #{action} #{recordable_type}"
          end

          def recording_studio_trashable_actor(explicit_actor)
            explicit_actor || RecordingStudioTrashable::Authorization.current_actor
          end

          def recording_studio_trashable_impersonator(explicit_impersonator)
            explicit_impersonator || RecordingStudioTrashable::Authorization.current_impersonator
          end

          def recording_studio_trashable_metadata(metadata)
            metadata.to_h
          end

          def recording_studio_trashable_assert_purge_targets!(targets)
            invalid_targets = targets.reject { |recording| recording.trashed_at.present? }
            return if invalid_targets.empty?

            raise RecordingStudioTrashable::PurgeTargetsNotTrashedError,
                  "Purging requires all targeted recordings to already be trashed"
          end

          def recording_studio_trashable_with_locked_targets(mode: :all)
            self.class.transaction do
              targets = recording_studio_trashable_targets(mode: mode)
              ids = targets.map(&:id).compact.uniq.sort
              if self.class.respond_to?(:lock)
                relation = self.class.recording_studio_trashable_including_trashed
                ids.each { |recording_id| relation.lock.find(recording_id) }
              end
              yield targets
            end
          end

          def recording_studio_trashable_targets(mode: :all)
            descendants = case mode
                          when :restore
                            recording_studio_trashable_descendants(prune_trash_roots: true)
                          else
                            recording_studio_trashable_descendants
                          end

            [self, *descendants]
          end

          def recording_studio_trashable_descendants(prune_trash_roots: false)
            descendants = []
            frontier = [id]

            until frontier.empty?
              children = self.class.recording_studio_trashable_including_trashed
                             .where(parent_recording_id: frontier)
                             .reorder(created_at: :asc)
                             .to_a
              next_frontier = []

              children.each do |child|
                next if prune_trash_roots && recording_studio_trashable_trash_root?(child)

                descendants << child

                next_frontier << child.id
              end

              frontier = next_frontier
            end

            descendants
          end

          def recording_studio_trashable_trash_root?(recording)
            if recording.respond_to?(:trash_root?)
              recording.trash_root?
            else
              !!recording.trash_root
            end
          end
        end
        # rubocop:enable Metrics/ModuleLength, Metrics/MethodLength
      end
    end
  end
end

module RecordingStudio
  module Capabilities
    Trashable = RecordingStudio::Trashable::Capabilities::Trashable
  end
end

RecordingStudio.register_capability(
  :trashable,
  RecordingStudio::Trashable::Capabilities::Trashable::RecordingMethods,
  source: "recording_studio_trashable"
)
