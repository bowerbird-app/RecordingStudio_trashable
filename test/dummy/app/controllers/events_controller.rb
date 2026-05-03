class EventsController < ApplicationController
  helper_method :event_recording_label, :event_actor_label, :event_metadata

  def show
    @events = RecordingStudio::Event.includes(:recording, :recordable, :previous_recordable, :actor, :impersonator).recent
  end

  private

  def event_recording_label(event)
    recording = event.recording
    return recordable_label(recording.recordable) if recording&.recordable.present?

    recordable = event.recordable || event.previous_recordable
    return recordable_label(recordable) if recordable.present?

    "#{event.recordable_type} ##{event.recordable_id.to_s.first(8)}"
  end

  def event_actor_label(event)
    actor_label = recordable_label(event.actor, missing: "System")
    return actor_label if event.impersonator.blank?

    "#{actor_label} via #{recordable_label(event.impersonator, missing: 'System')}"
  end

  def event_metadata(event)
    metadata = event.metadata.respond_to?(:to_h) ? event.metadata.to_h : {}
    return "-" if metadata.blank?

    JSON.pretty_generate(metadata)
  end

  def recordable_label(record, missing: nil)
    return missing if record.blank? && missing.present?
    return record.title if record.respond_to?(:title) && record.title.present?
    return record.name if record.respond_to?(:name) && record.name.present?
    return record.email if record.respond_to?(:email) && record.email.present?

    "#{record.class.name} ##{record.id.to_s.first(8)}"
  end
end
