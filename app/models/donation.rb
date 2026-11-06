class Donation < ApplicationRecord
  STATUSES = %w[pending processing successful failed cancelled].freeze
  FINAL_STATUSES = %w[successful failed cancelled].freeze
  MAX_AMOUNT = 10_000

  belongs_to :account
  belongs_to :terminal, optional: true

  validates :amount, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: MAX_AMOUNT }
  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_defaults, on: :create

  after_update_commit :send_confirmation_email_on_success, if: :saved_change_to_status?

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: "successful") }
  # Donations through the test provider never count as money received
  scope :live, -> { where(test: false) }

  def successful?
    status == "successful"
  end

  def final?
    status.in?(FINAL_STATUSES)
  end

  # Starts the payment on the terminal's reader
  def start_checkout!
    checkout_id = terminal.client.create_checkout(
      amount: amount, currency: currency, reader_id: terminal.provider_reader_id,
      description: "#{account.name} ##{id}", webhook_url: terminal.payment_connection.webhook_url
    )
    update!(checkout_id: checkout_id, status: "processing")
  rescue PaymentProviders::Error
    update!(status: "failed")
    raise
  end

  # Asks the provider for the outcome. Webhook and terminal polling can arrive together,
  # so the row lock keeps the confirmation email from going out twice.
  def sync_with_provider
    return if final? || checkout_id.blank? || terminal.nil?

    result = terminal.client.checkout_status(checkout_id)
    apply(result.state, transaction_code: result.transaction_code) unless result.state == "pending"
  end

  def apply(new_status, transaction_code: nil)
    with_lock do
      update!(status: new_status, transaction_code: transaction_code || self.transaction_code) unless final?
    end
  end

  private

  def set_defaults
    self.status ||= "pending"
    self.currency ||= account&.currency
    self.test = terminal.test_mode? if terminal
  end

  def send_confirmation_email_on_success
    DonationMailer.confirmation_email(self).deliver_later if donor_email.present? && successful?
  end
end
