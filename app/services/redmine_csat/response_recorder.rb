# frozen_string_literal: true

module RedmineCsat
  # Records or updates the customer's answer for a survey request, then keeps
  # the follow-up issue in sync.
  class ResponseRecorder
    Result = Struct.new(:status, :response, keyword_init: true) do
      def success? = %i[created updated unchanged].include?(status)
    end

    def initialize(csat_request, rating:, comment: nil, remote_ip: nil)
      @csat_request = csat_request
      @rating = rating
      @comment = comment
      @remote_ip = remote_ip
    end

    def call
      status = nil
      previous = nil
      response = nil

      RedmineCsatRequest.transaction do
        @csat_request.lock!
        response = RedmineCsatResponse.find_by(request_id: @csat_request.id)
        if response.nil?
          if @rating
            response = create_response
            status = :created
          else
            status = :invalid
          end
        elsif !response.editable?
          status = :locked
        else
          previous = { rating: response.rating, comment: response.comment }
          response.rating = @rating if @rating
          response.comment = @comment.presence unless @comment.nil?
          if response.changed?
            response.save!
            status = :updated
          else
            status = :unchanged
          end
        end
      end

      FollowUpSync.new(response, previous: previous).call if %i[created updated].include?(status)
      Result.new(status: status, response: response)
    rescue ActiveRecord::RecordNotUnique
      Result.new(status: :locked, response: @csat_request.reload.csat_response)
    end

    private

    def create_response
      response = RedmineCsatResponse.create!(
        csat_request: @csat_request, issue: @csat_request.issue, project: @csat_request.project,
        customer_user: @csat_request.customer_user, agent_user: @csat_request.agent_user,
        rating: @rating, comment: @comment.presence, responded_at: Time.current, ip_hash: ip_hash
      )
      @csat_request.update!(responded_at: response.responded_at)
      response
    end

    def ip_hash
      return nil if @remote_ip.blank?

      OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base.to_s, @remote_ip.to_s)
    end
  end
end
