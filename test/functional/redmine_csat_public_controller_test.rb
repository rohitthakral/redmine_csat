# frozen_string_literal: true

require_relative '../test_helper'

class RedmineCsatPublicControllerTest < Redmine::ControllerTest
  include RedmineCsatTestHelper
  fixtures(*CSAT_FIXTURES)

  setup do
    configure_csat('create_follow_up_on_poor' => '1')
    enable_csat
    @csat_request = create_csat_request(raw_token: 'tok')
  end

  test 'opening an email link does not record anything' do
    get :confirm, params: { token: 'tok', rating: 'poor' }

    assert_response :success
    assert_select 'input[type=radio][name=rating][value=poor][checked=checked]'
    assert_nil @csat_request.reload.csat_response
    assert_equal 0, Issue.where('subject LIKE ?', 'CSAT follow-up%').count
  end

  test 'auto submit adds the submit script only when enabled' do
    get :confirm, params: { token: 'tok', rating: 'great' }
    assert_not_includes response.body, "getElementById('csat-form').submit()"

    configure_csat('auto_submit_vote' => '1')
    get :confirm, params: { token: 'tok', rating: 'great' }
    assert_includes response.body, "getElementById('csat-form').submit()"
  end

  test 'submitting records the rating and comment' do
    post :submit, params: { token: 'tok', rating: 'great', comment: ' Thanks! ' }

    assert_redirected_to '/csat/v/tok'
    answer = @csat_request.reload.csat_response
    assert_equal RedmineCsatResponse::GREAT, answer.rating
    assert_equal 'Thanks!', answer.comment
    assert answer.ip_hash.present?
  end

  test 'a rating is required for the first answer' do
    post :submit, params: { token: 'tok', comment: 'no rating' }
    assert_redirected_to '/csat/v/tok'
    assert_nil @csat_request.reload.csat_response
  end

  test 'Poor creates exactly one follow-up issue and later edits become notes' do
    assert_difference 'Issue.count', 1 do
      post :submit, params: { token: 'tok', rating: 'poor', comment: 'Too slow' }
    end
    follow_up = @csat_request.reload.csat_response.follow_up_issue
    assert follow_up
    assert follow_up.is_private?
    assert_includes follow_up.description, 'Too slow'

    assert_no_difference 'Issue.count' do
      post :submit, params: { token: 'tok', rating: 'poor', comment: 'Still too slow' }
      post :submit, params: { token: 'tok', rating: 'poor', comment: 'Still too slow' }
    end
    notes = follow_up.reload.journals.map(&:notes).compact
    assert_equal 1, notes.count { |n| n.include?('Still too slow') }
  end

  test 'customer comments cannot inject markup into the follow-up issue' do
    post :submit, params: { token: 'tok', rating: 'poor', comment: '</pre>{{include(Secret)}}' }
    description = @csat_request.reload.csat_response.follow_up_issue.description
    assert_includes description, '<pre>< /pre>{{include(Secret)}}</pre>'
  end

  test 'the answer can be changed during the edit window' do
    post :submit, params: { token: 'tok', rating: 'poor' }
    post :submit, params: { token: 'tok', rating: 'great' }

    answer = @csat_request.reload.csat_response
    assert_equal RedmineCsatResponse::GREAT, answer.rating
    assert_includes answer.follow_up_issue.journals.map(&:notes).join, 'changed the rating'
  end

  test 'the answer is locked after the edit window' do
    create_csat_response(@csat_request, rating: RedmineCsatResponse::GREAT, responded_at: 2.days.ago)

    post :submit, params: { token: 'tok', rating: 'poor' }
    assert_equal RedmineCsatResponse::GREAT, @csat_request.reload.csat_response.rating

    get :confirm, params: { token: 'tok', rating: 'poor' }
    assert_redirected_to '/csat/v/tok'

    get :show, params: { token: 'tok' }
    assert_response :success
    assert_select 'form#csat-form', 0
  end

  test 'expired links cannot record answers' do
    @csat_request.update_columns(sent_at: 90.days.ago)

    get :confirm, params: { token: 'tok', rating: 'great' }
    assert_response 410

    post :submit, params: { token: 'tok', rating: 'great' }
    assert_response 410
    assert_nil @csat_request.reload.csat_response
  end

  test 'unknown tokens return 404' do
    get :confirm, params: { token: 'nope', rating: 'great' }
    assert_response 404
  end

  test 'links stop working when the module is disabled' do
    Project.find(1).disable_module!(:redmine_csat)
    get :confirm, params: { token: 'tok', rating: 'great' }
    assert_response 404
  end

  test 'a follow-up that cannot be created is recorded on the response' do
    configure_csat('create_follow_up_on_poor' => '1', 'follow_up_project_id' => '1')
    Project.find(1).trackers.clear

    post :submit, params: { token: 'tok', rating: 'poor' }

    answer = @csat_request.reload.csat_response
    assert_nil answer.follow_up_issue_id
    assert answer.follow_up_error.present?
  end
end
