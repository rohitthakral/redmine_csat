# frozen_string_literal: true

namespace :redmine_csat do
  desc 'Apply the CSAT retention settings: clear old IP hashes and delete old survey data'
  task purge: :environment do
    result = RedmineCsat::RetentionPurger.new.call
    puts "[redmine_csat] cleared #{result[:ip_hashes_cleared]} IP hashes, " \
         "deleted #{result[:requests_deleted]} survey requests"
  end
end
