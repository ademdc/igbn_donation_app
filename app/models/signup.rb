# Self-service registration: creates an account, its owner and a first terminal in test
# mode, so the terminal can be tried before any payment provider is connected.
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :organisation_name, :string
  attribute :subdomain, :string
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :terms, :boolean
  attribute :locale, :string

  validates :terms, acceptance: { accept: true }

  attr_reader :account, :user

  def self.suggest_subdomain(name)
    I18n.transliterate(name.to_s).downcase
      .gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      .first(40).delete_suffix("-")
  end

  def save
    @account = Account.new(name: organisation_name, subdomain: subdomain.presence || self.class.suggest_subdomain(organisation_name))
    @account.locales = [locale, *Account::LOCALES].uniq if locale.present?
    @user = @account.users.build(name: name, email: email, password: password, locale: locale)

    valid = [valid?, @account.valid?, @user.valid?].all?
    copy_errors
    return false unless valid

    Account.transaction do
      @account.save!
      connection = @account.payment_connections.create!(provider: PaymentProviders::TestMode.key)
      @account.terminals.create!(name: "Terminal 1", slug: "terminal1", payment_connection: connection)
    end
    true
  rescue ActiveRecord::RecordNotUnique
    errors.add(:subdomain, :taken)
    false
  end

  private

  def copy_errors
    { name: :organisation_name, subdomain: :subdomain }.each do |from, to|
      @account.errors[from].each { |message| errors.add(to, message) }
    end
    %i[name email password].each do |attribute|
      @user.errors[attribute].each { |message| errors.add(attribute, message) }
    end
  end
end
