# "Find my account" on the marketing site: emails the login links for every
# account the address belongs to, without revealing whether any exist.
class AccountLookupsController < MarketingController
  def new
  end

  def create
    email = params[:email].to_s.strip.downcase
    users = User.includes(:account).where(email: email).where.not(account_id: nil).to_a

    AccountMailer.with(email: email, users: users, locale: I18n.locale.to_s).login_links.deliver_later if users.any?
    redirect_to marketing_login_path(locale: I18n.locale), notice: t("app.account_lookups.sent")
  end
end
