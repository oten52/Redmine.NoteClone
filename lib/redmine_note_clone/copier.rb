# frozen_string_literal: true

module RedmineNoteClone
  class Copier
    def initialize(source, user, raw)
      @source = source
      @user = user
      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      @params = hash.deep_symbolize_keys
    end

    def call
      direct? ? copy_direct : copy_edited
    end

    private

    def direct?
      @params[:mode].to_s == 'direct'
    end

    def copy_direct
      journals = RedmineNoteClone.note_journals(@source, @user)
      raise Error, I18n.t(:redmine_note_clone_no_notes) if journals.empty?

      targets = Targets.related_writable(@source, @user)
      raise Error, I18n.t(:redmine_note_clone_no_related) if targets.empty?

      plans = journals.map { |journal|
        {
          journal: journal,
          text: journal.notes.to_s,
          files: RedmineNoteClone.files_for(@source, journal),
          include_source: true
        }
      }
      copy_plans(targets, plans, false)
    end

    def copy_edited
      journals = RedmineNoteClone.note_journals(@source, @user).index_by(&:id)
      plans = Array(@params[:notes]).map { |entry| plan_from(entry, journals) }.compact
      raise Error, I18n.t(:redmine_note_clone_no_notes) if plans.empty?

      targets, skipped = resolve_targets(Array(@params[:target_ids]))
      if targets.empty?
        return failure(skipped.first&.dig(:reason) || I18n.t(:redmine_note_clone_no_targets), skipped)
      end

      result = copy_plans(targets, plans, truthy?(@params[:notify], false))
      result[:skipped] = skipped + result[:skipped]
      result[:error] = nil if result[:copied_to].any?
      result
    end

    def plan_from(entry, journals)
      entry = entry.to_h.deep_symbolize_keys
      journal = journals[entry[:journal_id].to_i]
      return if journal.nil?

      text = entry.key?(:text) ? entry[:text].to_s : journal.notes.to_s
      raise Error, I18n.t(:redmine_note_clone_failed) if text.length > 200_000

      files = RedmineNoteClone.files_for(@source, journal)
      if entry.key?(:attachment_ids)
        allowed = Array(entry[:attachment_ids]).map(&:to_i)
        files = files.select { |file| allowed.include?(file.id) }
      end
      {
        journal: journal,
        text: text,
        files: files,
        include_source: truthy?(@params[:include_source], true)
      }
    end

    def resolve_targets(raw_ids)
      targets = []
      skipped = []
      raw_ids.map(&:to_i).select(&:positive?).uniq.first(40).each do |id|
        if id == @source.id
          skipped << { id: id, reason: I18n.t(:redmine_note_clone_same_issue) }
          next
        end
        issue = Issue.visible(@user).find_by(id: id)
        if issue.nil?
          skipped << { id: id, reason: I18n.t(:redmine_note_clone_not_found) }
          next
        end
        unless RedmineNoteClone.writable?(issue, @user)
          skipped << { id: id, subject: issue.subject.to_s, reason: I18n.t(:redmine_note_clone_cannot_add) }
          next
        end
        targets << issue
      end
      [targets, skipped]
    end

    def copy_plans(targets, plans, notify)
      copied = []
      skipped = []
      warnings = []
      targets.each do |target|
        begin
          count, notes = write_target(target, plans, notify)
          warnings.concat(notes)
          if count.positive?
            copied << target
          else
            skipped << {
              id: target.id,
              subject: target.subject.to_s,
              reason: notes.first || I18n.t(:redmine_note_clone_no_notes)
            }
          end
        rescue Error => e
          skipped << { id: target.id, subject: target.subject.to_s, reason: e.message }
        rescue StandardError => e
          Rails.logger.error("[redmine_note_clone] #{e.class}: #{e.message}")
          skipped << { id: target.id, subject: target.subject.to_s, reason: I18n.t(:redmine_note_clone_failed) }
        end
      end

      Rails.logger.info(
        "[redmine_note_clone] user=#{@user.id} source=#{@source.id} " \
        "copied=#{copied.map(&:id).join(',')} skipped=#{skipped.map { |row| row[:id] }.join(',')}"
      )

      if copied.empty?
        failure(skipped.first&.dig(:reason) || I18n.t(:redmine_note_clone_none), skipped, warnings)
      else
        {
          message: I18n.t(
            :redmine_note_clone_success,
            count: plans.size,
            issues: copied.map { |issue| "##{issue.id}" }.join(', ')
          ),
          error: nil,
          note_count: plans.size,
          copied_to: copied.map { |issue| { id: issue.id, subject: issue.subject.to_s } },
          skipped: skipped,
          warnings: warnings.uniq
        }
      end
    end

    def write_target(target, plans, notify)
      warnings = []
      written = 0
      Issue.transaction do
        used_names = target.attachments.map(&:filename)
        reused = {}
        plans.each do |plan|
          if plan[:journal].private_notes? && !@user.allowed_to?(:set_notes_private, target.project)
            warnings << I18n.t(:redmine_note_clone_private_skipped)
            next
          end
          body, uploads, note_warnings = render_note(plan, used_names, reused)
          warnings.concat(note_warnings)
          next if body.blank?

          write_note(target, body, plan[:journal].private_notes?, notify, uploads)
          written += 1
          target.reload
        end
        raise ActiveRecord::Rollback if written.zero?
      end
      [written, warnings.uniq]
    end

    def render_note(plan, used_names, reused)
      warnings = []
      selected = plan[:files]
      selected_ids = selected.map(&:id)
      body = plan[:text].to_s
      RedmineNoteClone.files_for(@source, plan[:journal]).each do |attachment|
        next if selected_ids.include?(attachment.id)

        body = Text.strip_filename(body, attachment.filename)
      end

      uploads = []
      embedded = []
      selected.each do |attachment|
        if reused.key?(attachment.id)
          embedded << [reused[attachment.id], attachment.image?]
          body = Text.rewrite_filename(body, attachment.filename, reused[attachment.id])
          next
        end
        unless attachment.readable?
          warnings << I18n.t(:redmine_note_clone_file_missing)
          body = Text.strip_filename(body, attachment.filename)
          next
        end
        new_name = unique_name(prefixed_name(attachment.filename), used_names)
        reused[attachment.id] = new_name
        uploads << [attachment, new_name]
        embedded << [new_name, attachment.image?]
        body = Text.rewrite_filename(body, attachment.filename, new_name)
      end
      body = Text.ensure_embedded(body, embedded)
      body = "#{source_header(plan[:journal])}#{body}" if plan[:include_source]
      [body.strip, uploads, warnings]
    end

    def write_note(target, text, private_notes, notify, uploads)
      reset_journal(target)
      journal = target.init_journal(@user, text)
      journal.notes = text
      journal.private_notes = private_notes
      journal.notify = notify

      opened = []
      saved = []
      begin
        unless uploads.empty?
          result = target.save_attachments(uploads.map { |attachment, new_name|
            upload = Upload.new(attachment.diskfile, new_name, attachment.content_type)
            opened << upload
            { 'file' => upload }
          })
          failed = Array(result[:unsaved])
          if failed.any?
            message = failed.flat_map { |item| item.errors.full_messages }.reject(&:blank?).join(', ')
            raise Error, (message.presence || I18n.t(:redmine_note_clone_file_rejected))
          end
          saved = Array(result[:files])
        end
        unless target.save
          message = target.errors.full_messages.reject(&:blank?).join(', ')
          raise Error, (message.presence || I18n.t(:redmine_note_clone_failed))
        end
        if journal.new_record?
          journal.journalized = target
          journal.save!
        end
        link_saved_files(target, journal, saved)
      ensure
        opened.each(&:close)
      end
    end

    def link_saved_files(target, journal, saved)
      saved.each do |attachment|
        attachment.reload
        if attachment.container_id != target.id
          attachment.update_columns(container_type: 'Issue', container_id: target.id)
        end
        next if journal.nil? || journal.new_record?
        next if journal.details.any? { |detail|
          detail.property == 'attachment' && detail.prop_key.to_s == attachment.id.to_s
        }

        journal.details.create!(
          property: 'attachment',
          prop_key: attachment.id.to_s,
          value: attachment.filename
        )
      end
    end

    def source_header(journal)
      I18n.t(
        :redmine_note_clone_source_line,
        id: @source.id,
        author: journal.user&.name.presence || '-',
        time: Payload.local_time(journal.created_on, @user)
      ) + "\n\n"
    end

    def prefixed_name(filename)
      prefix = "#{@source.id}-"
      ext = File.extname(filename.to_s)
      base = File.basename(filename.to_s, ext)
      keep = 240 - prefix.length - ext.length
      keep = 1 if keep < 1
      "#{prefix}#{base[0, keep]}#{ext}"
    end

    def unique_name(desired, used)
      name = desired
      index = 2
      while used.include?(name)
        ext = File.extname(desired)
        base = File.basename(desired, ext)
        name = "#{base}-#{index}#{ext}"
        index += 1
        break if index > 50
      end
      used << name
      name
    end

    def reset_journal(issue)
      issue.clear_journal if issue.respond_to?(:clear_journal)
      issue.instance_variable_set(:@current_journal, nil)
      issue.instance_variable_set(:@saved_attachments, nil)
      issue.instance_variable_set(:@unsaved_attachments, nil)
    end

    def truthy?(value, default)
      return default if value.nil?

      ActiveModel::Type::Boolean.new.cast(value)
    end

    def failure(message, skipped, warnings = [])
      {
        message: nil,
        error: message,
        note_count: 0,
        copied_to: [],
        skipped: skipped,
        warnings: warnings.uniq
      }
    end

    class Upload
      attr_reader :original_filename, :content_type

      def initialize(path, filename, content_type)
        @path = path
        @original_filename = filename
        @content_type = content_type.to_s
        @io = nil
      end

      def size
        File.size(@path)
      end

      def read(*args)
        @io ||= File.open(@path, 'rb')
        @io.read(*args)
      end

      def close
        @io&.close
        @io = nil
      end
    end
  end
end
