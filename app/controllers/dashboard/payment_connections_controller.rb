module Dashboard
  class PaymentConnectionsController < BaseController
    before_action :set_provider_and_connection, only: [:edit, :update, :verify, :destroy]

    def index
      @connections = @account.payment_connections.index_by(&:provider)
    end

    def edit
    end

    def update
      @connection.merge_credentials(params.fetch(:credentials, {}).permit(*@connection.client_class.fields.map(&:key)))

      if @connection.save && @connection.verify
        redirect_to dashboard_payment_connections_path, notice: t("app.payments.connected", provider: t("payment_providers.#{@connection.provider}.name"))
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def verify
      if @connection.verify
        redirect_to dashboard_payment_connections_path, notice: t("app.payments.verified")
      else
        redirect_to dashboard_payment_connections_path, alert: @connection.errors.full_messages.to_sentence
      end
    end

    def destroy
      if @connection.destroy
        redirect_to dashboard_payment_connections_path, notice: t("app.payments.removed")
      else
        redirect_to dashboard_payment_connections_path, alert: t("app.payments.in_use")
      end
    end

    private

    # The id is the provider key, so a provider can be connected before a record exists
    def set_provider_and_connection
      provider = params[:id].presence_in(PaymentProviders.connectable.map(&:key))
      raise ActiveRecord::RecordNotFound unless provider

      @connection = @account.payment_connections.find_or_initialize_by(provider: provider)
    end
  end
end
