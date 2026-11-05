# frozen_string_literal: true

module RedmineCsat
  # Applies the retention settings. Run it regularly with
  # `rake redmine_csat:purge` (for example from cron).
  class RetentionPurger
    def call
      { ip_hashes_cleared: clear_ip_hashes, requests_deleted: delete_old_requests }
    end

    private

    def clear_ip_hashes
      days = Settings.ip_hash_retention_days
      return 0 unless days.positive?

      RedmineCsatResponse.where.not(ip_hash: nil)
                         .where('responded_at < ?', days.days.ago)
                         .update_all(ip_hash: nil)
    end

    def delete_old_requests
      days = Settings.data_retention_days
      return 0 unless days.positive?

      old = RedmineCsatRequest.where('sent_at < ?', days.days.ago)
      RedmineCsatResponse.where(request_id: old.select(:id)).delete_all
      old.delete_all
    end
  end
end
