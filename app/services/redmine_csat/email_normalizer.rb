module RedmineCsat
  class EmailNormalizer
    PATTERN = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
    def self.call(email)
      value = email.to_s.strip.downcase
      value.match?(PATTERN) ? value : nil
    end
  end
end
