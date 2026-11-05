# frozen_string_literal: true

# Links in the survey email only display a confirmation page (GET is safe for
# email security scanners). The rating is recorded by the POST.
get  'csat/v/:token/:rating', to: 'redmine_csat_public#confirm', as: :redmine_csat_vote,
                              constraints: { rating: /poor|okay|great/ }
get  'csat/v/:token', to: 'redmine_csat_public#show', as: :redmine_csat_show
post 'csat/v/:token', to: 'redmine_csat_public#submit', as: :redmine_csat_submit
get  'projects/:project_id/csat', to: 'redmine_csat_reports#index', as: :redmine_csat_report
