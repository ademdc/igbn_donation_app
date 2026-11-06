module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    user = User.from_session(session[:user_id], session[:user_fingerprint])
    # Account users only count as signed in on their own account's host
    user = nil if user && !user.admin? && user.account_id != Current.account&.id
    @current_user = user
  end

  def sign_in(user)
    locale = session[:locale]
    reset_session
    session[:locale] = locale
    session[:user_id] = user.id
    session[:user_fingerprint] = user.session_fingerprint
    user.update_column(:last_login_at, Time.current)
    @current_user = user
  end

  def sign_out
    reset_session
    @current_user = nil
  end

  def require_user
    redirect_to login_path unless current_user
  end
end
