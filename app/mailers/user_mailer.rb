class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @account = @user.account
    @url = @account.url("/password_resets/#{@user.generate_token_for(:password_reset)}/edit")

    mail to: @user.email, subject: t("mailers.password_reset.subject", account: @account.name)
  end
end
