module PaymentProviders
  # Lets an account try its terminal without a provider or a card reader. A payment
  # "completes" a few seconds after it starts, unless the amount ends in .13, which fails.
  class TestMode < Base
    APPROVAL_SECONDS = 6

    def self.key
      "test"
    end

    def self.requires_reader?
      false
    end

    def self.test_mode?
      true
    end

    def verify
      true
    end

    def create_checkout(amount:, currency:, reader_id:, description:, webhook_url:)
      outcome = (amount * 100).round % 100 == 13 ? "failed" : "successful"
      "test_#{outcome}_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
    end

    def checkout_status(checkout_id)
      _, outcome, started_at = checkout_id.split("_")
      return CheckoutResult.new(state: "pending") if Time.current.to_i - started_at.to_i < APPROVAL_SECONDS

      CheckoutResult.new(state: outcome, transaction_code: "TEST#{checkout_id.last(8).upcase}")
    end

    def reader_status(reader_id)
      ReaderStatus.new(online: true, state: "IDLE")
    end
  end
end
