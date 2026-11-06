module Admin
  class SessionsController < ApplicationController
    include Authentication
    include EnglishLocale

    layout "admin"

    def new
      redirect_to admin_dashboard_path if current_user&.admin?
    end

    def create
      user = User.admins.authenticate_by(email: params[:email], password: params[:password])

      if user
        sign_in(user)
        redirect_to admin_dashboard_path, notice: "Successfully logged in"
      else
        flash.now[:alert] = "Invalid email or password"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out
      redirect_to admin_login_path, notice: "Logged out"
    end
  end
end
