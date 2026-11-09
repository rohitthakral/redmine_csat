# frozen_string_literal: true

require_relative '../test_helper'

class RedmineCsatSurveyEmailTest < ActiveSupport::TestCase
  include RedmineCsatTestHelper
  fixtures(*CSAT_FIXTURES)

  VOTE_URLS = { 'great' => 'https://x.test/great', 'okay' => 'https://x.test/okay', 'poor' => 'https://x.test/poor' }.freeze

  setup { configure_csat }

  def build_email(**attrs)
    RedmineCsat::SurveyEmail.new(**{
      issue_id: 42, issue_subject: 'Printer <on fire> & "smoking"', project_name: 'eCookbook',
      agent_name: 'Dave Lopper', customer_name: 'John Smith', vote_urls: VOTE_URLS,
      issue_url: 'https://redmine.test/issues/42', sent_at: Time.current
    }.merge(attrs))
  end

  test 'renderer escapes values in HTML and leaves unknown tags' do
    html = RedmineCsat::TemplateRenderer.render('{{a}} {{ b }} {{c}}', { a: '<b>', b: 'x' }, html: true)
    assert_equal '&lt;b&gt; x {{c}}', html
  end

  test 'renderer inserts safe blocks only in HTML mode' do
    safe = { block: '<hr>' }
    assert_equal '<hr>', RedmineCsat::TemplateRenderer.render('{{block}}', {}, html: true, safe: safe)
    assert_equal '{{block}}', RedmineCsat::TemplateRenderer.render('{{block}}', {}, safe: safe)
  end

  test 'renderer does not expand placeholders inside values' do
    assert_equal '{{b}}', RedmineCsat::TemplateRenderer.render('{{a}}', { a: '{{b}}', b: 'no' })
  end

  test 'built-in email contains escaped details and all three rating links' do
    email = build_email
    html = email.html

    VOTE_URLS.each_value { |url| assert_includes html, url }
    assert_includes html, 'Printer &lt;on fire&gt; &amp; &quot;smoking&quot;'
    assert_includes html, 'Hi John Smith,'
    assert_includes html, 'https://redmine.test/issues/42'
    assert_no_match(/\{\{\s*\w+\s*\}\}/, html)

    text = email.text
    assert_includes text, 'Great: https://x.test/great'
    assert_includes text, 'Printer <on fire> & "smoking"'
    assert_no_match(/\{\{\s*\w+\s*\}\}/, text)
  end

  test 'greets without a name when the customer is not a Redmine user' do
    assert_includes build_email(customer_name: nil).text, 'Hello,'
  end

  test 'subject supports placeholders and the old %{} syntax' do
    configure_csat('mail_subject' => 'Was #%{issue_id} 100%% fixed? {{issue_subject}}')
    assert_equal 'Was #42 100% fixed? Printer <on fire> & "smoking"', build_email.subject
  end

  test 'design settings are applied and validated' do
    configure_csat('email_company_name' => 'Acme', 'email_brand_color' => '#123abc',
                   'email_logo_url' => 'https://cdn.test/logo.png', 'email_show_issue_details' => '0')
    html = build_email.html
    assert_includes html, '#123abc'
    assert_includes html, 'src="https://cdn.test/logo.png"'
    assert_not_includes html, 'Dave Lopper'

    configure_csat('email_brand_color' => 'red;background:url(x)', 'email_logo_url' => 'javascript:alert(1)')
    html = build_email.html
    assert_includes html, RedmineCsat::Settings::DEFAULT_BRAND_COLOR
    assert_not_includes html, 'javascript:'
  end

  test 'custom intro and footer are plain text with placeholders' do
    configure_csat('email_intro' => "Dear {{customer_name}}\n\n<script>x</script>", 'email_footer' => 'Bye from {{company_name}}')
    html = build_email.html
    assert_includes html, 'Dear John Smith'
    assert_includes html, '&lt;script&gt;x&lt;/script&gt;'
    assert_includes build_email.text, 'Bye from'
  end

  test 'custom templates replace the built-in design' do
    configure_csat('email_custom_html' => '<p>{{greeting}}</p>{{rating_buttons}}<i>{{issue_subject}}</i>',
                   'email_custom_text' => 'Rate us: {{great_url}}')
    email = build_email

    assert email.custom_html?
    assert_includes email.html, '<p>Hi John Smith,</p>'
    assert_includes email.html, 'https://x.test/poor'
    assert_includes email.html, '<i>Printer &lt;on fire&gt;'
    assert_equal "Rate us: https://x.test/great\n", email.text
    assert_empty email.warnings
  end

  test 'custom templates without rating links fall back to the built-in one with a warning' do
    configure_csat('email_custom_html' => '<p>Thanks {{nope}}</p>')
    email = build_email

    refute email.custom_html?
    assert_includes email.html, 'https://x.test/great'
    assert_equal 2, email.warnings.size
    assert(email.warnings.any? { |w| w.include?('{{nope}}') })
  end

  test 'the survey email is multipart and uses the custom template' do
    enable_csat
    configure_csat('email_custom_html' => '<h1>{{prompt}}</h1>{{rating_buttons}}')
    request = create_csat_request(raw_token: 'tok')

    mail = RedmineCsatMailer.survey(request.id, 'tok')

    assert mail.multipart?
    assert_includes mail.html_part.body.to_s, '<h1>How was your experience with us?</h1>'
    assert_includes mail.html_part.body.to_s, '/csat/v/tok/great'
    assert_includes mail.text_part.body.to_s, '/csat/v/tok/poor'
    assert_equal 'auto-generated', mail['Auto-Submitted'].to_s
  end
end
