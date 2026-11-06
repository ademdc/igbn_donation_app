class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.mail_from }
  layout "mailer"

  around_action :with_mail_locale

  private

  def with_mail_locale(&action)
    locale = params&.dig(:user)&.locale || params&.dig(:locale)
    locale = "de" unless Account::LOCALES.include?(locale)
    I18n.with_locale(locale, &action)
  end
end
