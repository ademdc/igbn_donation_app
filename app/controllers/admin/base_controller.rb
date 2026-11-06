module Admin
  class BaseController < ApplicationController
    include Authentication

    include EnglishLocale

    layout "admin"
    before_action :authenticate_admin

    private

    def authenticate_admin
      redirect_to admin_login_path unless current_user&.admin?
    end
  end
end
