module Dashboard
  class DonationsController < BaseController
    PER_PAGE = 50

    def index
      scope = @account.donations.includes(:terminal).recent
      scope = scope.where(status: params[:status]) if Donation::STATUSES.include?(params[:status])
      scope = scope.where(terminal_id: params[:terminal_id]) if params[:terminal_id].present?

      @terminals = @account.terminals.order(:name)
      @page = [params[:page].to_i, 1].max
      @total = scope.count
      @donations = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    end
  end
end
