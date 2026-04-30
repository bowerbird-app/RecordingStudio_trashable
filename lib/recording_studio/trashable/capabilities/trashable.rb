# frozen_string_literal: true

module RecordingStudioTrashable
  module RecordingScopes
    extend ActiveSupport::Concern

    included do
      scope :recording_studio_trashable_active, -> { unscope(where: :trashed_at).where(trashed_at: nil) }
      scope :recording_studio_trashable_trashed, -> { unscope(where: :trashed_at).where.not(trashed_at: nil) }
      scope :recording_studio_trashable_including_trashed, -> { unscope(where: :trashed_at) }
      scope :recording_studio_trashable_trash_bin, lambda {
        recording_studio_trashable_trashed.reorder(trashed_at: :desc, updated_at: :desc)
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

        module RecordingMethods
          include RecordingStudio::Capability

          def recording_studio_trashable_trash!(actor: nil, impersonator: nil, metadata: {}, include_children: false)
            recording_studio_trashable_assert_capability!
            recording_studio_trashable_authorize!(:trash, actor: actor)
            recording_studio_trashable_with_locked_targets(include_children: include_children) do |targets|
              targets.reverse_each do |recording|
                next if recording.trashed_at.present?

                recording.log_event!(
                  action: "trashed",
                  actor: recording_studio_trashable_actor(actor),
                  impersonator: recording_studio_trashable_impersonator(impersonator),
                  metadata: recording_studio_trashable_metadata(metadata, include_children: include_children)
                )
                recording.update!(trashed_at: Time.current)
              end
            end
            reload
          end

          def recording_studio_trashable_restore!(actor: nil, impersonator: nil, metadata: {}, include_children: false)
            recording_studio_trashable_assert_capability!
            recording_studio_trashable_authorize!(:restore, actor: actor)
            recording_studio_trashable_with_locked_targets(include_children: include_children) do |targets|
              targets.each do |recording|
                next if recording.trashed_at.blank?

                recording.log_event!(
                  action: "restored",
                  actor: recording_studio_trashable_actor(actor),
                  impersonator: recording_studio_trashable_impersonator(impersonator),
                  metadata: recording_studio_trashable_metadata(metadata, include_children: include_children)
                )
                recording.update!(trashed_at: nil)
              end
            end
            reload
          end

          def recording_studio_trashable_purge!(actor: nil, impersonator: nil, metadata: {}, include_children: false)
            recording_studio_trashable_assert_capability!
            recording_studio_trashable_authorize!(:purge, actor: actor)
            recording_studio_trashable_assert_purgeable!(include_children: include_children)
            recording_studio_trashable_with_locked_targets(include_children: include_children) do |targets|
              targets.reverse_each do |recording|
                recording.log_event!(
                  action: "purged",
                  actor: recording_studio_trashable_actor(actor),
                  impersonator: recording_studio_trashable_impersonator(impersonator),
                  metadata: recording_studio_trashable_metadata(metadata, include_children: include_children)
                )
                recording.destroy!
              end
            end
            self
          end

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

          def recording_studio_trashable_metadata(metadata, include_children:)
            metadata.to_h.merge(include_children: include_children == true)
          end

          def recording_studio_trashable_assert_purgeable!(include_children:)
            return if include_children
            return if recording_studio_trashable_descendants.empty?

            raise ArgumentError, "Purging a recording with descendants requires include_children: true"
          end

          def recording_studio_trashable_with_locked_targets(include_children: false)
            self.class.transaction do
              targets = recording_studio_trashable_targets(include_children: include_children)
              ids = targets.map(&:id).compact.uniq.sort
              ids.each { |recording_id| self.class.lock.find(recording_id) } if self.class.respond_to?(:lock)
              yield targets
            end
          end

          def recording_studio_trashable_targets(include_children:)
            include_children ? [self, *recording_studio_trashable_descendants] : [self]
          end

          def recording_studio_trashable_descendants
            descendants = []
            frontier = [id]

            until frontier.empty?
              children = self.class.recording_studio_trashable_including_trashed
                                   .where(parent_recording_id: frontier)
                                   .reorder(created_at: :asc)
                                   .to_a
              descendants.concat(children)
              frontier = children.map(&:id)
            end

            descendants
          end
        end
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
  RecordingStudio::Trashable::Capabilities::Trashable::RecordingMethods
)
