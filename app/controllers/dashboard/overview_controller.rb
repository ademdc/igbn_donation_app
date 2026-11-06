module Dashboard
  class OverviewController < BaseController
    PERIODS = [7, 30, 90].freeze

    def show
      @days = params[:days].to_i.presence_in(PERIODS) || 30
      @stats = DashboardPresenter.new(@account, days: @days)
    end
  end
end
