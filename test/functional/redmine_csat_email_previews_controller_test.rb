# frozen_string_literal: true

require_relative '../test_helper'

class RedmineCsatEmailPreviewsControllerTest < Redmine::ControllerTest
  include RedmineCsatTestHelper
  fixtures(*CSAT_FIXTURES)

  setup do
    configure_csat
    ActionMailer::Base.deliveries.clear
  end

  test 'administrators can preview unsaved settings' do
    @request.session[:user_id] = 1

    post :show, params: { settings: { 'email_company_name' => 'Unsaved Co', 'enabled' => '0',
                                      'email_custom_html' => '<p>{{bogus}}</p>' } }

    assert_response :success
    assert_select 'iframe[sandbox][srcdoc*="Unsaved Co"]'
    assert_select 'p.warning', minimum: 1
    # Only email settings are taken from the form, and nothing is saved.
    assert RedmineCsat::Settings.enabled?
    assert_nil RedmineCsat::Settings.email_company_name
  end

  test 'administrators can send themselves a test email' do
    @request.session[:user_id] = 1

    post :deliver, params: { settings: { 'rating_prompt' => 'Rate us!' } }

    assert_response :success
    mail = ActionMailer::Base.deliveries.last
    assert_equal [User.find(1).mail], mail.to
    assert_includes mail.html_part.body.to_s, 'Rate us!'
    assert_match(/\A\[/, mail.subject)
  end

  test 'non-administrators are refused' do
    @request.session[:user_id] = 2
    post :show, params: { settings: {} }
    assert_response 403

    post :deliver, params: { settings: {} }
    assert_response 403
    assert_empty ActionMailer::Base.deliveries
  end
end
