module Dashboard
  class BaseController < ApplicationController
    include AccountScoped
    include Authentication
    include AppLocale

    layout "app"
    before_action :require_user
    before_action :set_account

    private

    def set_account
      @account = Current.account
    end
  end
end
