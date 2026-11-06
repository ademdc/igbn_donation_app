# Payment results posted by the providers. SumUp doesn't sign these, so the secret token in
# the URL identifies the account, and a success is only believed once the provider's API
# confirms it, as SumUp advises. A failure has nothing to confirm: a terminated checkout
# never becomes a transaction.
class WebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    connection = PaymentConnection.find_by(provider: params[:provider], webhook_token: params[:token])
    return head :not_found unless connection

    event = connection.client.parse_webhook(JSON.parse(request.raw_post))
    donation = event && connection.account.donations.find_by(checkout_id: event.checkout_id)

    if donation
      event.state == "failed" ? donation.apply("failed") : donation.sync_with_provider(after_cancel: true)
    end
    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue PaymentProviders::Error => e
    # Not 2xx, so the provider tries again
    Rails.logger.warn "Webhook for donation #{donation&.id} not confirmed: #{e.message}"
    head :service_unavailable
  end
end
