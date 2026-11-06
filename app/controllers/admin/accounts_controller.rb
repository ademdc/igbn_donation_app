module Admin
  class AccountsController < BaseController
    PER_PAGE = 50
    BILLING_FILTERS = { "trialing" => :trialing, "trial_expired" => :trial_expired, "paying" => :paying,
                        "payment_due" => :payment_due, "suspended" => :suspended }.freeze

    before_action :set_account, except: :index

    def index
      scope = Account.search(params[:q])
      scope = scope.public_send(BILLING_FILTERS.fetch(params[:status])) if BILLING_FILTERS.key?(params[:status])

      @page = [params[:page].to_i, 1].max
      @total = scope.count
      @accounts = scope.order(created_at: :desc).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
        .includes(:users, :terminals, :payment_connections)
    end

    def show
      @users = @account.users.order(:created_at)
      @terminals = @account.terminals.includes(:payment_connection).order(:created_at)
      @connections = @account.payment_connections.order(:created_at)
      @stats = DashboardPresenter.new(@account, days: 30)
      @awaiting_transfers = @account.payments.awaiting_transfer.includes(:account).order(:created_at)
      @payments = @account.payments.where.not(status: "pending").recent
    end

    def update
      if @account.update(admin_params)
        redirect_to admin_account_path(@account), notice: "Account updated"
      else
        redirect_to admin_account_path(@account), alert: @account.errors.full_messages.to_sentence
      end
    end

    def extend_trial
      days = params[:days].to_i.clamp(1, 365)
      base = [@account.trial_ends_at, Time.current].compact.max
      @account.update!(trial_ends_at: base + days.days)
      redirect_to admin_account_path(@account), notice: "Trial extended by #{days} days"
    end

    # Opens the account dashboard as its owner, for support
    def impersonate
      owner = @account.owner
      return redirect_to admin_account_path(@account), alert: "This account has no owner" unless owner

      Rails.logger.info "Admin #{current_user.email} impersonated #{owner.email} (account #{@account.subdomain})"
      redirect_to @account.url("/session/#{owner.generate_token_for(:handover)}"), allow_other_host: true
    end

    private

    def set_account
      @account = Account.find(params[:id])
    end

    def admin_params
      params.require(:account).permit(:status, :name)
    end
  end
end
