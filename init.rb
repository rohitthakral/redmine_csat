# frozen_string_literal: true

# Redmine 5.1+ loads plugin init.rb files from inside a `to_prepare` block, so
# patches are applied directly here. Wrapping them in another `to_prepare`
# would register a callback that never runs during boot in production.
unless Issue.included_modules.include?(RedmineCsat::IssuePatch)
  Issue.include(RedmineCsat::IssuePatch)
end

Redmine::Plugin.register :redmine_csat do
  name 'Redmine CSAT'
  author 'Target Integration'
  description 'Customer satisfaction surveys for Redmine issues with customer-role and owner-email recipient resolution.'
  version '0.2.0'
  requires_redmine version_or_higher: '6.1.2'

  settings default: RedmineCsat::Settings::DEFAULTS, partial: 'settings/redmine_csat_settings'

  project_module :redmine_csat do
    permission :view_csat_reports, { redmine_csat_reports: [:index] }
  end

  menu :project_menu,
       :redmine_csat,
       { controller: 'redmine_csat_reports', action: 'index' },
       caption: :label_redmine_csat,
       after: :activity,
       param: :project_id
end
