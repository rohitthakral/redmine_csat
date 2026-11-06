# frozen_string_literal: true

module RedmineCsat
  # Fills `{{placeholder}}` tags in admin-editable templates.
  #
  # Templates are plain text, never ERB, so a template cannot run code. In HTML
  # mode every value is HTML-escaped unless it is listed in `safe`, which is
  # reserved for blocks the plugin builds itself. Each tag is replaced in a
  # single pass, so values containing `{{...}}` are not expanded again.
  # Unknown tags are left in place so mistakes show up in the preview.
  class TemplateRenderer
    TAG = /\{\{\s*([a-z_]+)\s*\}\}/

    def self.render(template, vars, html: false, safe: {})
      template.to_s.gsub(TAG) do |match|
        key = Regexp.last_match(1).to_sym
        if html && safe.key?(key)
          safe[key].to_s
        elsif vars.key?(key)
          html ? ERB::Util.html_escape(vars[key].to_s) : vars[key].to_s
        else
          match
        end
      end
    end

    # Placeholders used in a template, for validation and warnings.
    def self.placeholders(template)
      template.to_s.scan(TAG).flatten.map(&:to_sym).uniq
    end
  end
end
