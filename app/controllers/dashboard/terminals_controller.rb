module Dashboard
  class TerminalsController < BaseController
    before_action :set_terminal, only: [:edit, :update, :destroy]

    def index
      @terminals = @account.terminals.includes(:payment_connection).order(:created_at)
      # Restarts checks a deploy interrupted; the job is a no-op once a certificate is issued
      @terminals.select { |terminal| terminal.certificate_status == "pending" }.each { |terminal| TerminalCertificateJob.perform_later(terminal) }
    end

    def new
      @terminal = @account.terminals.new(payment_connection: default_connection, slug: "terminal#{@account.terminals.count + 1}")
    end

    def create
      @terminal = @account.terminals.new(terminal_params.merge(account: @account))

      if @terminal.save_with_pairing
        redirect_to dashboard_terminals_path, notice: t("app.terminals.created", host: @terminal.hostname)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @terminal.assign_attributes(terminal_params.except(:slug))

      if @terminal.save_with_pairing
        redirect_to dashboard_terminals_path, notice: t("app.terminals.saved")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @terminal.destroy
        redirect_to dashboard_terminals_path, notice: t("app.terminals.deleted")
      else
        redirect_to dashboard_terminals_path, alert: t("app.terminals.has_donations")
      end
    end

    private

    def set_terminal
      @terminal = @account.terminals.find(params[:id])
    end

    def default_connection
      @account.live_connections.first || @account.payment_connections.first
    end

    def terminal_params
      params.require(:terminal).permit(:name, :slug, :payment_connection_id, :provider_reader_id, :pairing_code, :active)
    end
  end
end
