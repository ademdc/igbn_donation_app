# Signs a user in on their account's subdomain after signing up on the marketing site,
# or when the super admin opens a dashboard for support.
class HandoversController < ApplicationController
  include AccountScoped
  include Authentication

  def show
    user = User.find_by_token_for(:handover, params[:token])

    if user && user.account_id == Current.account.id
      session[:locale] = user.locale
      sign_in(user)
      redirect_to dashboard_path(welcome: params[:welcome].presence)
    else
      redirect_to login_path
    end
  end
end
