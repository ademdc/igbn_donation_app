# What an account pays us for its plan, by bank transfer. Not to be confused with
# donations, which go straight to the account's own payment provider.
class Payment < ApplicationRecord
  KINDS = %w[subscription addon].freeze
  STATUSES = %w[pending approved declined].freeze

  belongs_to :account
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :extra_terminals, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: Account::MAX_EXTRA_TERMINALS }

  scope :approved, -> { where(status: "approved") }
  scope :recent, -> { order(created_at: :desc) }
  # Transfers an account has announced but we haven't seen arrive yet
  scope :awaiting_transfer, -> { where(status: "pending") }

  # One year from today, or from the end of the trial or paid year, so paying early loses
  # nothing. extra_terminals is the total number of extra terminals for that year.
  def self.subscription_for(account, user:, extra_terminals:)
    start = [account.paid_until, account.trial_ends_at, Time.current].compact.max
    monthly = Account::BASE_PRICE_CENTS + extra_terminals * Account::EXTRA_TERMINAL_PRICE_CENTS
    new(account: account, user: user, kind: "subscription", extra_terminals: extra_terminals,
        amount_cents: monthly * 12, period_start: start, period_end: start + 1.year)
  end

  # Extra terminals during a paid year, charged per started month until paid_until
  def self.addon_for(account, user:, extra_terminals:)
    new(account: account, user: user, kind: "addon", extra_terminals: extra_terminals,
        amount_cents: extra_terminals * Account::EXTRA_TERMINAL_PRICE_CENTS * account.paid_months_left,
        period_start: Time.current, period_end: account.paid_until)
  end

  def pending? = status == "pending"
  def approved? = status == "approved"
  def subscription? = kind == "subscription"

  # Payment reference for the transfer, short enough for every banking app
  def reference
    "DD-#{id}"
  end

  def description
    if subscription?
      "#{account.name} #{period_start.to_date} – #{period_end.to_date}"
    else
      "#{account.name} +#{extra_terminals} terminal(s) until #{period_end.to_date}"
    end
  end

  def approve!(confirmed_by:)
    with_lock do
      return unless pending?

      update!(status: "approved", approved_at: Time.current, confirmed_by: confirmed_by)
      if subscription?
        account.update!(paid_until: period_end, extra_terminals: extra_terminals)
      else
        account.update!(extra_terminals: account.extra_terminals + extra_terminals)
      end
    end
    AccountMailer.with(payment: self, user: account.owner).payment_confirmed.deliver_later if account.owner
  end

  def decline!
    with_lock { update!(status: "declined") if pending? }
  end
end
