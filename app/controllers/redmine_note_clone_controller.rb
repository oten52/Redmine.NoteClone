# frozen_string_literal: true

class RedmineNoteCloneController < ApplicationController
  before_action :require_login
  before_action :find_source_issue

  def show
    render json: RedmineNoteClone::Payload.build(@issue, User.current, view_context)
  end

  def lookup
    raw = params[:issue_ids]
    text = raw.is_a?(Array) ? raw.join(',') : raw.to_s
    rows = RedmineNoteClone::Targets.lookup(@issue, User.current, text.scan(/\d+/))
    render json: { issues: rows.map { |row| lookup_json(row) } }
  end

  def create
    result = RedmineNoteClone::Copier.new(@issue, User.current, copy_params).call
    status = result[:error].present? && result[:copied_to].blank? ? :unprocessable_entity : :ok
    render json: result, status: status
  rescue RedmineNoteClone::Error => e
    render json: { error: e.message, copied_to: [], skipped: [], warnings: [] }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[redmine_note_clone] #{e.class}: #{e.message}\n#{Array(e.backtrace).first(12).join("\n")}")
    render json: { error: I18n.t(:redmine_note_clone_failed), copied_to: [], skipped: [], warnings: [] }, status: :internal_server_error
  end

  private

  def find_source_issue
    @issue = Issue.visible.find(params[:id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t(:redmine_note_clone_not_found) }, status: :not_found
    false
  end

  def copy_params
    params.permit(:mode, :include_source, :notify, target_ids: [], notes: [:journal_id, :text, { attachment_ids: [] }])
  end

  def lookup_json(row)
    return { id: row[:id], writable: false, error: row[:error] } if row[:issue].nil?

    json = RedmineNoteClone::Payload.target_json(row, view_context)
    json[:error] = row[:reason] unless row[:writable]
    json
  end
end
