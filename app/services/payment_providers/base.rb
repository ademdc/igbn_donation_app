module PaymentProviders
  class Base
    def self.key
      raise NotImplementedError
    end

    # The credentials an owner enters
    def self.fields
      []
    end

    def self.requires_reader?
      true
    end

    def self.supports_pairing?
      false
    end

    def self.test_mode?
      false
    end

    def initialize(credentials = {})
      @credentials = credentials.to_h.with_indifferent_access
    end

    # Raises Error if the provider rejects the credentials
    def verify
      raise NotImplementedError
    end

    # Starts a payment on the reader. Returns the id to look the outcome up with.
    def create_checkout(amount:, currency:, reader_id:, description:, webhook_url:)
      raise NotImplementedError
    end

    # Returns a CheckoutResult with state "pending", "successful", "failed" or "cancelled"
    def checkout_status(checkout_id)
      raise NotImplementedError
    end

    # Stops a payment waiting on the reader. Raises Error if it's too late to stop it.
    def cancel_checkout(reader_id)
      raise NotImplementedError
    end

    # Returns a ReaderStatus
    def reader_status(reader_id)
      raise NotImplementedError
    end

    # Returns the provider's id for the newly paired reader
    def pair_reader(code:, name:)
      raise NotImplementedError
    end

    # Returns a WebhookEvent, or nil for events the app doesn't handle
    def parse_webhook(payload)
      nil
    end
  end
end
