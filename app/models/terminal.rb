class Terminal < ApplicationRecord
  belongs_to :account
  belongs_to :payment_connection
  has_many :donations, dependent: :restrict_with_error

  # Offered instead of the reader ID where the provider can pair a device from its code
  attr_accessor :pairing_code

  normalizes :slug, with: ->(value) { value.to_s.strip.downcase }

  validates :name, presence: true
  validates :slug, presence: true, length: { in: 1..30 }, uniqueness: { scope: :account_id },
    format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/ }
  validates :hostname, uniqueness: true
  validates :provider_reader_id, presence: true, if: -> { payment_connection&.client_class&.requires_reader? && pairing_code.blank? }
  validate :connection_belongs_to_account
  validate :hostname_free_of_accounts

  before_validation :set_hostname, on: :create
  before_validation :reset_reader_for_test_mode
  after_create_commit :request_certificate
  after_destroy_commit :remove_certificate

  scope :active, -> { where(active: true) }
  scope :awaiting_certificate, -> { where(certificate_status: "pending") }

  def self.for_host(host)
    find_by(hostname: host.to_s.downcase)
  end

  def url(path = "/")
    AppDomain.url(hostname, path)
  end

  def client
    payment_connection.client
  end

  def test_mode?
    payment_connection.client_class.test_mode?
  end

  def live?
    certificate_status.in?([nil, "issued"])
  end

  # Saves the terminal, first pairing a new reader from its code if the owner gave one
  def save_with_pairing
    return false unless valid?

    self.provider_reader_id = client.pair_reader(code: pairing_code, name: name) if pairing_code.present?
    save
  rescue PaymentProviders::Error => e
    errors.add(:pairing_code, I18n.t("payment_errors.#{e.code}", default: I18n.t("payment_errors.provider_error")))
    false
  end

  private

  def set_hostname
    return if account.nil? || slug.blank?

    self.hostname =
      if Rails.configuration.x.terminal_hosts == "flat"
        "#{slug}-#{account.subdomain}.#{AppDomain.host}"
      else
        "#{slug}.#{account.subdomain}.#{AppDomain.host}"
      end
    self.certificate_status = "pending" if TerminalCertificates.needed?
  end

  def reset_reader_for_test_mode
    self.provider_reader_id = nil if payment_connection && !payment_connection.client_class.requires_reader?
  end

  def connection_belongs_to_account
    errors.add(:payment_connection, :invalid) if payment_connection && payment_connection.account_id != account_id
  end

  def hostname_free_of_accounts
    errors.add(:slug, :taken) if hostname_changed? && Account.for_host(hostname)
  end

  def request_certificate
    TerminalCertificateJob.perform_later(self) if certificate_status == "pending"
  end

  def remove_certificate
    TerminalCertificates.remove(hostname) if certificate_status.present?
  end
end
