# frozen_string_literal: true

require_relative '../test_helper'

class RedmineCsatReportsControllerTest < Redmine::ControllerTest
  include RedmineCsatTestHelper
  fixtures(*CSAT_FIXTURES)

  setup do
    configure_csat
    enable_csat
    Role.find(1).add_permission!(:view_csat_reports)
    @request.session[:user_id] = 2

    create_csat_response(create_csat_request(raw_token: 'a'), rating: RedmineCsatResponse::GREAT,
                                                             comment: 'Lovely')
    create_csat_response(create_csat_request(issue: Issue.find(2), raw_token: 'b'),
                         rating: RedmineCsatResponse::POOR)
    create_csat_request(issue: Issue.find(3), raw_token: 'c')
  end

  test 'shows score and response rate' do
    get :index, params: { project_id: 1 }

    assert_response :success
    assert_select 'table.list tbody tr', 2
    assert_includes response.body, '50.0%' # CSAT: 1 Great out of 2 responses
    assert_includes response.body, '66.7%' # response rate: 2 of 3 delivered
  end

  test 'undelivered surveys do not count as sent' do
    create_csat_request(issue: Issue.find(7), raw_token: 'd', delivered_at: nil)
    get :index, params: { project_id: 1 }
    assert_includes response.body, '66.7%'
  end

  test 'issues the user cannot see are left out' do
    Issue.find(2).update_columns(is_private: true, author_id: 1, assigned_to_id: nil)
    Role.find(1).update!(issues_visibility: 'own')

    get :index, params: { project_id: 1 }

    assert_response :success
    assert_select 'table.list tbody tr', 1
  end

  test 'filters by date sent' do
    RedmineCsatRequest.find_by(issue_id: 2).update_columns(sent_at: 40.days.ago)
    get :index, params: { project_id: 1, from: 7.days.ago.to_date.iso8601 }
    assert_select 'table.list tbody tr', 1
  end

  test 'exports CSV' do
    get :index, params: { project_id: 1, format: 'csv' }

    assert_response :success
    assert_equal 'text/csv', response.media_type
    assert_includes response.body, 'Lovely'
  end

  test 'requires the view_csat_reports permission' do
    Role.find(1).remove_permission!(:view_csat_reports)
    get :index, params: { project_id: 1 }
    assert_response 403
  end

  test 'requires the project module' do
    Project.find(1).disable_module!(:redmine_csat)
    get :index, params: { project_id: 1 }
    assert_response 403
  end
end
