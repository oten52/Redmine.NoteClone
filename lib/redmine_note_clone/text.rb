# frozen_string_literal: true

module RedmineNoteClone
  module Text
    module_function

    def filename_token?(fragment, filename)
      return false if filename.blank?

      fragment.to_s.match?(token_pattern(filename))
    end

    def strip_filename(text, filename)
      result = text.to_s.dup
      return result if filename.blank?

      result.gsub!(/!\[[^\]]*\]\([^)\n]*\)/) { |match| filename_token?(match, filename) ? '' : match }
      result.gsub!(/![^!\n]*!/) { |match| filename_token?(match, filename) ? '' : match }
      result.gsub!(/attachment:"[^"\n]+"/) { |match| filename_token?(match, filename) ? '' : match }
      result.gsub!(/attachment:\S+/) { |match| filename_token?(match, filename) ? '' : match }
      result
    end

    def rewrite_filename(text, old_name, new_name)
      return text.to_s if old_name.blank? || old_name == new_name

      text.to_s.gsub(token_pattern(old_name), new_name)
    end

    def ensure_embedded(text, entries)
      result = text.to_s.dup
      entries.each do |name, image|
        next if name.blank? || result.include?(name)

        macro = image ? "!#{name}!" : "attachment:#{name}"
        result = "#{result.rstrip}\n\n#{macro}"
      end
      result.strip
    end

    def token_pattern(filename)
      /(?<![\w.\-])#{Regexp.escape(filename)}(?![\w\-])/
    end
  end
end
