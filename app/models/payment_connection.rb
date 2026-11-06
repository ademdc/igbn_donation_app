# An account's link to a payment provider. The API keys are encrypted at rest and never
# sent back to the browser. Providers post their results to webhook_url, whose token is
# the only thing identifying the account, because SumUp does not sign its webhooks.
class PaymentConnection < ApplicationRecord
  belongs_to :account
  has_many :terminals, dependent: :restrict_with_error

  serialize :credentials, coder: JSON
  encrypts :credentials

  has_secure_token :webhook_token, length: 48

  validates :provider, inclusion: { in: PaymentProviders.keys }, uniqueness: { scope: :account_id }
  validate :required_credentials_present

  def client_class
    PaymentProviders.fetch(provider)
  end

  def client
    client_class.new(credentials || {})
  end

  # Blank form fields keep the stored secret, so owners can change one key at a time
  def merge_credentials(values)
    fields = client_class.fields.map { |field| field.key.to_s }
    self.credentials = (credentials || {}).merge(values.to_h.slice(*fields).compact_blank)
    self.verified_at = nil
  end

  # Checks the keys against the provider, returns false and sets an error if they're rejected
  def verify
    client.verify
    update!(verified_at: Time.current)
    true
  rescue PaymentProviders::Error => e
    errors.add(:base, I18n.t("payment_errors.#{e.code}", default: I18n.t("payment_errors.provider_error")))
    false
  end

  def masked(key)
    value = credentials&.dig(key.to_s).to_s
    "••••#{value.last(4)}" if value.present?
  end

  def webhook_url
    AppDomain.marketing_url("/webhooks/#{provider}/#{webhook_token}")
  end

  private

  def required_credentials_present
    return unless PaymentProviders.keys.include?(provider)

    client_class.fields.select(&:required).each do |field|
      errors.add(:credentials, :blank) if credentials&.dig(field.key.to_s).blank?
    end
  end
end
