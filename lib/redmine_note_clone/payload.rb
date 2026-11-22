# frozen_string_literal: true

module RedmineNoteClone
  module Payload
    module_function

    def build(issue, user, view)
      {
        source: { id: issue.id, subject: issue.subject.to_s },
        notes: RedmineNoteClone.note_journals(issue, user).map { |journal| note_json(issue, journal, user, view) },
        targets: Targets.collect(issue, user).map { |row| target_json(row, view) }
      }
    end

    def note_json(issue, journal, user, view)
      {
        id: journal.id,
        author: journal.user&.name.to_s,
        created_on: local_time(journal.created_on, user),
        private: journal.private_notes?,
        text: journal.notes.to_s,
        files: RedmineNoteClone.files_for(issue, journal).map { |attachment| file_json(attachment, view) }
      }
    end

    def file_json(attachment, view)
      {
        id: attachment.id,
        filename: attachment.filename.to_s,
        image: attachment.image?,
        url: view.url_for(controller: 'attachments', action: 'download', id: attachment.id, filename: attachment.filename, only_path: true),
        thumbnail: (attachment.thumbnailable? ? view.url_for(controller: 'attachments', action: 'thumbnail', id: attachment.id, only_path: true) : nil)
      }
    end

    def target_json(row, view)
      issue = row[:issue]
      {
        id: row[:id],
        subject: row[:subject],
        project: row[:project],
        tracker: row[:tracker],
        status: row[:status],
        kind: row[:kind],
        label: row[:label],
        selected: row[:selected],
        writable: row[:writable],
        reason: row[:reason],
        url: view.issue_path(issue)
      }
    end

    def local_time(time, user)
      return '' unless time

      zone = user.time_zone if user.respond_to?(:time_zone)
      zone = Time.zone if zone.blank?
      time.in_time_zone(zone).strftime('%d.%m.%Y %H:%M')
    end
  end
end
