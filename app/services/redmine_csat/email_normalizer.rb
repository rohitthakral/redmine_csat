# frozen_string_literal: true

module RedmineCsat
  # Validates and normalises a single email address. Returns nil when invalid.
  class EmailNormalizer
    PATTERN = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/

    def self.call(email)
      value = email.to_s.strip.downcase
      value.match?(PATTERN) ? value : nil
    end
  end
end
