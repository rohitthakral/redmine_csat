# frozen_string_literal: true

get  'csat/v/:token/:rating', to: 'redmine_csat_public#vote', as: :redmine_csat_vote,
                                 constraints: { rating: /poor|okay|great/ }
post 'csat/v/:token/comment', to: 'redmine_csat_public#comment', as: :redmine_csat_comment
get  'projects/:project_id/csat', to: 'redmine_csat_reports#index', as: :redmine_csat_report
