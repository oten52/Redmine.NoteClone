# frozen_string_literal: true

module RedmineNoteClone
  module Targets
    module_function

    def collect(source, user)
      found = {}
      source.relations.each do |relation|
        other_id = relation.issue_from_id == source.id ? relation.issue_to_id : relation.issue_from_id
        next if other_id.blank? || other_id == source.id

        label = relation.respond_to?(:label_for) ? relation.label_for(source) : I18n.t(:redmine_note_clone_related)
        found[other_id] = { kind: 'related', label: label, selected: true }
      end

      if source.parent_id.present? && !found.key?(source.parent_id)
        found[source.parent_id] = { kind: 'parent', label: I18n.t(:redmine_note_clone_parent), selected: false }
      end

      Issue.visible(user).where(parent_id: source.id).order(:id).limit(100).pluck(:id).each do |child_id|
        next if found.key?(child_id)

        found[child_id] = { kind: 'child', label: I18n.t(:redmine_note_clone_child), selected: false }
      end

      issues = Issue.visible(user).where(id: found.keys).includes(:project, :tracker, :status).index_by(&:id)
      rows = []
      found.each do |id, meta|
        issue = issues[id]
        next unless issue

        rows << describe(issue, user, meta[:kind], meta[:label], meta[:selected])
      end
      rows.sort_by { |row| [row[:selected] ? 0 : 1, row[:id]] }
    end

    def related_writable(source, user)
      collect(source, user).select { |row| row[:kind] == 'related' && row[:writable] }.map { |row| row[:issue] }
    end

    def describe(issue, user, kind, label, selected)
      writable = RedmineNoteClone.writable?(issue, user)
      {
        issue: issue,
        id: issue.id,
        subject: issue.subject.to_s,
        project: issue.project&.name.to_s,
        tracker: issue.tracker&.name.to_s,
        status: issue.status&.name.to_s,
        kind: kind,
        label: label.to_s,
        selected: selected && writable,
        writable: writable,
        reason: writable ? nil : I18n.t(:redmine_note_clone_cannot_add)
      }
    end

    def lookup(source, user, raw_ids)
      ids = raw_ids.map(&:to_i).select(&:positive?).uniq.first(20)
      ids.map do |id|
        if id == source.id
          { id: id, writable: false, error: I18n.t(:redmine_note_clone_same_issue) }
        else
          issue = Issue.visible(user).includes(:project, :tracker, :status).find_by(id: id)
          if issue.nil?
            { id: id, writable: false, error: I18n.t(:redmine_note_clone_not_found) }
          else
            row = describe(issue, user, 'manual', I18n.t(:redmine_note_clone_manual), true)
            row[:error] = row[:reason]
            row
          end
        end
      end
    end
  end
end
