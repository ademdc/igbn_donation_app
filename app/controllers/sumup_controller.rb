class SumupController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_sumup_signature, only: :sumup

  SUPPORTED_EVENT_TYPES = ['solo.transaction.updated'].freeze

  def checkout_return_url
    handle_transaction_update(parsed_payload) if valid_event_type?
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def parsed_payload
    @parsed_payload ||= JSON.parse(request.body.read)
  end

  def valid_event_type?
    return head(:bad_request) unless SUPPORTED_EVENT_TYPES.include?(parsed_payload['event_type'])
    true
  end

  def handle_transaction_update(payload)
    checkout_id = payload.dig('payload', 'client_transaction_id')
    status = payload.dig('payload', 'status')
    
    donation = Donation.find_by(checkout_id: checkout_id)
    
    if donation&.update(status: status)
      head :ok
    else
      head :not_found
    end
  end

  def verify_sumup_signature
    signature = request.headers['X-SumUp-Signature']
    calculated = calculate_signature(request.body.read)
    
    head :unauthorized unless Rack::Utils.secure_compare(signature, calculated)
  end

  def calculate_signature(payload)
    secret = Rails.application.credentials.sumup[:webhook_secret]
    OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
  end
end