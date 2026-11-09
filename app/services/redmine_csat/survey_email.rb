# frozen_string_literal: true

module RedmineCsat
  # Builds the survey email (subject, HTML and plain text) from the email
  # settings and a set of `{{placeholder}}` values.
  #
  # The built-in design lives in config/email_templates/. Administrators can
  # adjust it through simple settings (company name, logo, colour, intro and
  # footer text) or replace it with their own HTML and text templates.
  class SurveyEmail
    include Redmine::I18n

    TEMPLATE_DIR = File.expand_path('../../../config/email_templates', __dir__)
    RATING_ORDER = %i[great okay poor].freeze
    RATING_LINK_PLACEHOLDERS = %i[rating_buttons great_url okay_url poor_url].freeze
    BUTTON_COLORS = { great: '#2e7d32', okay: '#b45309', poor: '#c62828' }.freeze
    ICONS = { great: "\u{1F642}", okay: "\u{1F610}", poor: "\u{1F641}" }.freeze
    FONT = "-apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"

    # Placeholders available in every template, with the locale key that
    # describes them on the settings page.
    PLACEHOLDERS = %i[
      greeting customer_name issue_id issue_subject issue_url project status agent_name
      company_name prompt great_url okay_url poor_url great_label okay_label poor_label
      expiry_date expiry_notice subject preheader hint intro footer brand_color logo_url
    ].freeze
    # Ready-made blocks. In HTML templates they are inserted as HTML; in text
    # templates as plain text.
    BLOCKS = %i[header intro_html footer_html issue_details rating_buttons].freeze

    def self.default_html_template = File.read(File.join(TEMPLATE_DIR, 'survey.html'))
    def self.default_text_template = File.read(File.join(TEMPLATE_DIR, 'survey.txt'))

    def self.for_request(csat_request, vote_urls:, issue_url: nil)
      issue = csat_request.issue
      new(
        issue_id: issue.id, issue_subject: issue.subject, project_name: issue.project&.name,
        status_name: issue.status&.name, agent_name: csat_request.agent_user&.name,
        customer_name: csat_request.customer_user&.name, vote_urls: vote_urls,
        issue_url: issue_url, sent_at: csat_request.sent_at
      )
    end

    # Example content for the preview and test emails.
    def self.sample(vote_urls:, customer_name: nil)
      new(
        issue_id: 1234, issue_subject: ::I18n.t(:text_csat_sample_issue_subject),
        project_name: ::I18n.t(:text_csat_sample_project), status_name: IssueStatus.where(is_closed: true).first&.name,
        agent_name: ::I18n.t(:text_csat_sample_agent), customer_name: customer_name,
        vote_urls: vote_urls, issue_url: nil, sent_at: Time.current
      )
    end

    def initialize(issue_id:, issue_subject:, vote_urls:, project_name: nil, status_name: nil,
                   agent_name: nil, customer_name: nil, issue_url: nil, sent_at: Time.current)
      @issue_id = issue_id
      @issue_subject = issue_subject.to_s
      @vote_urls = vote_urls.transform_keys(&:to_sym)
      @project_name = project_name.to_s
      @status_name = status_name.to_s
      @agent_name = agent_name.to_s
      @customer_name = customer_name.to_s
      @issue_url = issue_url.to_s
      @sent_at = sent_at
    end

    def subject
      # `%{name}` is the subject syntax used before 0.2.0; it is still accepted.
      template = Settings.mail_subject_template.gsub(/%\{(\w+)\}/, '{{\1}}').gsub('%%', '%')
      TemplateRenderer.render(template, base_vars).squish.truncate(250)
    end

    def html
      TemplateRenderer.render(html_template, html_vars, html: true, safe: html_blocks)
    end

    def text
      TemplateRenderer.render(text_template, html_vars.merge(text_blocks)).gsub(/\n{3,}/, "\n\n").strip + "\n"
    end

    # Problems with the custom templates, shown in the preview.
    def warnings
      list = []
      list.concat(template_warnings(Settings.email_custom_html, :html)) if Settings.email_custom_html
      list.concat(template_warnings(Settings.email_custom_text, :text)) if Settings.email_custom_text
      list
    end

    def custom_html? = valid_custom?(Settings.email_custom_html)
    def custom_text? = valid_custom?(Settings.email_custom_text)

    private

    def html_template = custom_html? ? Settings.email_custom_html : self.class.default_html_template
    def text_template = custom_text? ? Settings.email_custom_text : self.class.default_text_template

    # A custom template without any rating link would send an email nobody can
    # answer, so the built-in template is used instead.
    def valid_custom?(template)
      template.present? && TemplateRenderer.placeholders(template).intersect?(RATING_LINK_PLACEHOLDERS)
    end

    def template_warnings(template, kind)
      label = ::I18n.t(kind == :html ? :field_csat_email_custom_html : :field_csat_email_custom_text)
      list = []
      unless valid_custom?(template)
        list << ::I18n.t(:text_csat_template_missing_links, template: label)
      end
      unknown = TemplateRenderer.placeholders(template) - PLACEHOLDERS - BLOCKS - %i[language]
      if unknown.any?
        list << ::I18n.t(:text_csat_template_unknown_placeholders, template: label,
                                                                  names: unknown.map { |n| "{{#{n}}}" }.join(', '))
      end
      list
    end

    def labels = Settings.labels

    def base_vars
      @base_vars ||= begin
        vars = {
          language: ::I18n.locale.to_s,
          greeting: greeting,
          customer_name: @customer_name,
          issue_id: @issue_id,
          issue_subject: @issue_subject,
          issue_url: @issue_url,
          project: @project_name,
          status: @status_name,
          agent_name: @agent_name,
          company_name: company_name,
          prompt: Settings.prompt,
          expiry_date: expiry_date.to_s,
          expiry_notice: expiry_notice,
          brand_color: Settings.email_brand_color,
          logo_url: Settings.email_logo_url.to_s,
          hint: hint
        }
        RATING_ORDER.each do |rating|
          vars[:"#{rating}_url"] = @vote_urls[rating].to_s
          vars[:"#{rating}_label"] = labels[rating]
        end
        vars
      end
    end

    # Values for the body templates: the base values plus the rendered
    # subject, preheader, intro and footer as plain text.
    def html_vars
      @html_vars ||= base_vars.merge(subject: subject, preheader: preheader, intro: intro_text, footer: footer_text)
    end

    def greeting
      if @customer_name.present?
        ::I18n.t(:text_csat_greeting_named, name: @customer_name)
      else
        ::I18n.t(:text_csat_greeting)
      end
    end

    def company_name
      Settings.email_company_name || Setting.app_title.to_s
    end

    def expiry_date
      days = Settings.link_validity_days
      format_date((@sent_at || Time.current) + days.days) if days.positive?
    end

    def expiry_notice
      date = expiry_date
      date ? ::I18n.t(:text_csat_expiry_notice, date: date) : ''
    end

    def hint
      ::I18n.t(Settings.allow_comment? ? :text_csat_email_hint_comment : :text_csat_email_hint)
    end

    def preheader
      ::I18n.t(:text_csat_email_preheader, issue_id: @issue_id)
    end

    def intro_text
      TemplateRenderer.render(Settings.email_intro || ::I18n.t(:text_csat_email_intro_default), base_vars).strip
    end

    def footer_text
      TemplateRenderer.render(Settings.email_footer || ::I18n.t(:text_csat_email_footer_default), base_vars).strip
    end

    # --- HTML blocks ---------------------------------------------------------

    def html_blocks
      {
        header: header_html,
        intro_html: paragraphs_html(intro_text, 'margin:0 0 14px 0; font-size:16px; line-height:24px; color:#1f2937;'),
        footer_html: paragraphs_html(footer_text, 'margin:0 0 8px 0;'),
        issue_details: issue_details_html,
        rating_buttons: rating_buttons_html
      }
    end

    def header_html
      name = h(company_name)
      if Settings.email_logo_url
        %(<img src="#{h(Settings.email_logo_url)}" alt="#{name}" height="40" ) +
          %(style="display:block; height:40px; max-height:40px; width:auto; border:0; outline:none;">)
      else
        %(<div style="font-size:16px; line-height:24px; font-weight:600; color:#{Settings.email_brand_color};">#{name}</div>)
      end
    end

    def paragraphs_html(text, style)
      text.split(/\n\s*\n/).map do |paragraph|
        lines = paragraph.strip.split("\n").map { |line| h(line.strip) }
        %(<p style="#{style}">#{lines.join('<br>')}</p>)
      end.join("\n")
    end

    def issue_details_html
      return '' unless Settings.email_show_issue_details?

      meta = [@project_name, @agent_name.presence && ::I18n.t(:text_csat_handled_by, name: @agent_name)]
             .compact_blank.map { |part| h(part) }.join(' &middot; ')
      reference = h(::I18n.t(:label_csat_email_request, id: @issue_id))
      reference = %(<a href="#{h(@issue_url)}" style="color:#6b7280; text-decoration:underline;">#{reference}</a>) if @issue_url.present?

      <<~HTML.strip
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f9fafb; border:1px solid #e5e7eb; border-radius:6px;">
          <tr>
            <td style="padding:12px 16px; font-family:#{FONT}; font-size:14px; line-height:20px; color:#374151;">
              <div style="font-size:12px; line-height:18px; letter-spacing:0.04em; text-transform:uppercase; color:#6b7280;">#{reference}</div>
              <div style="font-weight:600; color:#111827;">#{h(@issue_subject)}</div>
              #{meta.present? ? %(<div style="color:#6b7280;">#{meta}</div>) : ''}
            </td>
          </tr>
        </table>
      HTML
    end

    # Bulletproof buttons: the colour sits on the table cell so Outlook shows
    # it, and the cells stack on narrow screens.
    def rating_buttons_html
      cells = RATING_ORDER.map do |rating|
        color = BUTTON_COLORS[rating]
        <<~HTML.strip
          <td class="csat-choice" width="33%" valign="top" style="padding:0 4px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="center" bgcolor="#{color}" style="border-radius:6px; background-color:#{color};">
                  <a href="#{h(@vote_urls[rating])}" target="_blank" style="display:block; padding:14px 8px; font-family:#{FONT}; font-size:16px; line-height:20px; font-weight:600; color:#ffffff; text-decoration:none; border-radius:6px;">#{ICONS[rating]}&nbsp;#{h(labels[rating])}</a>
                </td>
              </tr>
            </table>
          </td>
        HTML
      end
      %(<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>#{cells.join}</tr></table>)
    end

    # --- Text blocks ---------------------------------------------------------

    def text_blocks
      {
        header: company_name,
        intro_html: intro_text,
        footer_html: footer_text,
        issue_details: issue_details_text,
        rating_buttons: RATING_ORDER.map { |rating| "#{labels[rating]}: #{@vote_urls[rating]}" }.join("\n")
      }
    end

    def issue_details_text
      return '' unless Settings.email_show_issue_details?

      lines = ["#{::I18n.t(:label_csat_email_request, id: @issue_id)}: #{@issue_subject}"]
      lines << @project_name if @project_name.present?
      lines << ::I18n.t(:text_csat_handled_by, name: @agent_name) if @agent_name.present?
      lines << @issue_url if @issue_url.present?
      lines.join("\n")
    end

    def h(value) = ERB::Util.html_escape(value.to_s)
  end
end
