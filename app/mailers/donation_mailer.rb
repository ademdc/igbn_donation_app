class DonationMailer < ActionMailer::Base
  helper :application
  layout "donation_mailer"

  def confirmation_email(donation)
    @donation = donation
    @account = donation.account

    I18n.with_locale(donation.locale.presence_in(Account::LOCALES) || @account.default_locale) do
      mail(
        to: donation.donor_email,
        from: email_address_with_name(Mail::Address.new(Rails.configuration.x.mail_from).address, @account.name),
        reply_to: @account.owner&.email,
        subject: t("mailers.donation.subject", account: @account.name)
      )
    end
  end
end
