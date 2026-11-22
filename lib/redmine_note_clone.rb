# frozen_string_literal: true

module RedmineNoteClone
  class Error < StandardError; end

  module_function

  def note_journals(issue, user)
    table = Journal.table_name
    scope = issue.journals.
      includes(:user, :details).
      where("#{table}.notes IS NOT NULL AND #{table}.notes <> ''").
      order("#{table}.id")
    unless user.allowed_to?(:view_private_notes, issue.project)
      scope = scope.where("#{table}.private_notes = ? OR #{table}.user_id = ?", false, user.id)
    end
    scope.to_a.select { |journal| journal.notes.present? }
  end

  def any_visible_notes?(issue, user)
    table = Journal.table_name
    scope = issue.journals.where("#{table}.notes IS NOT NULL AND #{table}.notes <> ''")
    unless user.allowed_to?(:view_private_notes, issue.project)
      scope = scope.where("#{table}.private_notes = ? OR #{table}.user_id = ?", false, user.id)
    end
    scope.exists?
  end

  def writable?(issue, user)
    issue.notes_addable?(user) || issue.attributes_editable?(user)
  end

  def files_for(issue, journal)
    attachments = issue.attachments.to_a
    detail_ids = journal.details.select { |detail|
      detail.property == 'attachment' && detail.value.present?
    }.map { |detail| detail.prop_key.to_i }
    text = journal.notes.to_s
    attachments.select { |attachment|
      detail_ids.include?(attachment.id) || Text.filename_token?(text, attachment.filename)
    }
  end
end
