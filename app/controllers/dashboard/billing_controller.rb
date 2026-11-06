module Dashboard
  # The yearly plan and extra terminals, paid by bank transfer. The account gets the bank
  # details and a reference, and an admin marks the payment as paid once the money arrives.
  class BillingController < BaseController
    before_action :load_history

    def show
    end

    def create
      @account.assign_attributes(billing_params)

      unless @account.billing_details_complete? && @account.save
        @account.errors.add(:base, t("app.billing.details_missing")) if @account.errors.empty?
        return render :show, status: :unprocessable_entity
      end

      payment = build_payment
      return redirect_to dashboard_billing_path, alert: t("app.billing.nothing_to_pay") unless payment&.valid?

      # A new request replaces an open one
      @account.payments.awaiting_transfer.find_each(&:decline!)
      payment.save!
      AccountMailer.with(payment: payment, user: current_user).bank_transfer.deliver_later
      AdminMailer.with(payment: payment, locale: "en").bank_transfer_requested.deliver_later
      redirect_to dashboard_billing_path(anchor: "transfer"), notice: t("app.billing.transfer.requested")
    end

    private

    def load_history
      @payments = @account.payments.where.not(status: "pending").recent
    end

    def billing_params
      params.require(:account).permit(:billing_name, :billing_address, :billing_zip, :billing_city, :billing_email, :country)
    end

    def build_payment
      extra = params[:extra_terminals].to_i.clamp(0, Account::MAX_EXTRA_TERMINALS)

      if @account.paid? && params[:kind] == "addon"
        Payment.addon_for(@account, user: current_user, extra_terminals: extra) if extra.positive?
      else
        Payment.subscription_for(@account, user: current_user, extra_terminals: [extra, @account.extra_terminals_needed].max)
      end
    end
  end
end
