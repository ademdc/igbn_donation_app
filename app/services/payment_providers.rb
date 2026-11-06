# One interface for every card-reader provider. To add one, subclass Base, list it in
# PROVIDERS and add its name and fields to the `payment_providers` translations.
module PaymentProviders
  class Error < StandardError
    attr_reader :code

    def initialize(message = nil, code: :provider_error)
      super(message)
      @code = code
    end
  end

  Field = Struct.new(:key, :secret, :required, keyword_init: true)
  CheckoutResult = Struct.new(:state, :transaction_code, keyword_init: true)
  ReaderStatus = Struct.new(:online, :state, keyword_init: true)
  WebhookEvent = Struct.new(:checkout_id, :state, keyword_init: true)

  PROVIDERS = { "sumup" => "PaymentProviders::Sumup", "test" => "PaymentProviders::TestMode" }.freeze

  def self.keys
    PROVIDERS.keys
  end

  def self.fetch(key)
    PROVIDERS.fetch(key).constantize
  end

  # What an owner can connect in the dashboard
  def self.connectable
    keys.map { |key| fetch(key) }.reject(&:test_mode?)
  end
end
