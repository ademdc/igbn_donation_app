class Account < ApplicationRecord
  RESERVED_SUBDOMAINS = %w[www admin app api mail cable assets static help support status blog].freeze
  STATUSES = %w[active suspended].freeze
  CURRENCIES = %w[EUR CHF GBP USD SEK NOK DKK PLN].freeze
  LOCALES = %w[de bs en].freeze
  LOCALE_NAMES = { "de" => "Deutsch", "bs" => "Bosanski", "en" => "English" }.freeze
  COPY_KEYS = %w[title subtitle thank_you].freeze
  COPY_MAX_LENGTH = 300
  MAX_PRESET_AMOUNTS = 6
  COLOR_FORMAT = /\A#[0-9a-f]{6}\z/i

  # Destroyed in this order: terminals keep their donations, connections their terminals
  has_many :donations, dependent: :destroy
  has_many :terminals, dependent: :destroy
  has_many :payment_connections, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :brand_images, dependent: :destroy

  normalizes :subdomain, with: ->(value) { value.to_s.strip.downcase }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true, length: { in: 3..40 },
    format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/ }, exclusion: { in: RESERVED_SUBDOMAINS }
  validates :status, inclusion: { in: STATUSES }
  validates :currency, inclusion: { in: CURRENCIES }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates :primary_color, :accent_color, :background_color, format: { with: COLOR_FORMAT }
  validate :locales_supported
  validate :preset_amounts_sensible
  validate :terminal_copy_short
  validate :subdomain_free_of_terminals

  scope :active, -> { where(status: "active") }
  scope :suspended, -> { where(status: "suspended") }

  def self.search(query)
    return all if query.blank?
    pattern = "%#{sanitize_sql_like(query.strip)}%"
    where("accounts.name ILIKE :q OR accounts.subdomain ILIKE :q", q: pattern)
  end

  def self.for_host(host)
    host = host.to_s.downcase
    return unless host.end_with?(".#{AppDomain.host}")
    find_by(subdomain: host.delete_suffix(".#{AppDomain.host}"))
  end

  def host
    "#{subdomain}.#{AppDomain.host}"
  end

  def url(path = "/")
    AppDomain.url(host, path)
  end

  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  def owner
    users.order(:created_at).first
  end

  # "5, 10, 20" in the appearance form
  def preset_amounts_text
    preset_amounts.map { |amount| amount.to_d.frac.zero? ? amount.to_i : amount.to_f }.join(", ")
  end

  def preset_amounts_text=(text)
    self.preset_amounts = text.to_s.split(/[,;\s]+/).compact_blank.map { |value| value.tr(",", ".").to_d }
  end

  def default_locale
    locales.first
  end

  # The owner's text for this language, or the standard wording
  def terminal_text(key, locale = I18n.locale)
    terminal_copy.dig(locale.to_s, key.to_s).presence || I18n.t("terminal.defaults.#{key}", locale: locale)
  end

  # Digests of the uploaded images, without loading their bytes. Doubles as the cache buster.
  def image_digest(kind)
    @image_digests ||= brand_images.pluck(:kind, :digest).to_h
    @image_digests[kind.to_s]
  end

  def live_connections
    payment_connections.reject { |connection| connection.client_class.test_mode? }
  end

  private

  def locales_supported
    errors.add(:locales, :blank) if locales.empty?
    errors.add(:locales, :inclusion) if (locales - LOCALES).any?
  end

  def preset_amounts_sensible
    errors.add(:preset_amounts, :blank) if preset_amounts.empty?
    errors.add(:preset_amounts, :too_long, count: MAX_PRESET_AMOUNTS) if preset_amounts.size > MAX_PRESET_AMOUNTS
    errors.add(:preset_amounts, :invalid) unless preset_amounts.all? { |amount| amount.positive? && amount <= Donation::MAX_AMOUNT }
  end

  def terminal_copy_short
    texts = terminal_copy.values.flat_map { |copy| copy.is_a?(Hash) ? copy.values : [copy] }
    errors.add(:terminal_copy, :too_long, count: COPY_MAX_LENGTH) if texts.any? { |text| text.to_s.length > COPY_MAX_LENGTH }
  end

  # With flat terminal hosts, "front-acme" could be a terminal as well as an account
  def subdomain_free_of_terminals
    errors.add(:subdomain, :taken) if subdomain_changed? && Terminal.exists?(hostname: host)
  end
end
