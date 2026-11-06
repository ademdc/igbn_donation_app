class PasswordResetsController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  layout "app"
  before_action :find_user_by_token, only: [:edit, :update]

  def new
  end

  def create
    if (user = Current.account.users.find_by(email: params[:email].to_s.strip.downcase))
      UserMailer.with(user: user, locale: I18n.locale.to_s).password_reset.deliver_later
    end

    # Same answer whether or not the address exists
    redirect_to login_path, notice: t("app.password_resets.sent")
  end

  def edit
  end

  def update
    if @user.update(password_params)
      sign_in(@user)
      redirect_to dashboard_path, notice: t("app.password_resets.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_user_by_token
    @user = User.find_by_token_for(:password_reset, params[:token])
    unless @user && @user.account_id == Current.account.id
      redirect_to new_password_reset_path, alert: t("app.password_resets.invalid_link")
    end
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation).tap do |p|
      # has_secure_password skips blank passwords on update, so require one explicitly
      p[:password] = nil if p[:password].blank?
    end
  end
end
