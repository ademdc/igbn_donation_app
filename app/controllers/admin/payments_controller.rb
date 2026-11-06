module Admin
  # Bank transfers are confirmed by hand once the money shows up in the account
  class PaymentsController < BaseController
    before_action :set_payment

    def confirm
      @payment.approve!(confirmed_by: current_user.email)
      redirect_back_or_to admin_account_path(@payment.account), notice: "#{@payment.reference} marked as paid"
    end

    def cancel
      @payment.decline!
      redirect_back_or_to admin_account_path(@payment.account), notice: "#{@payment.reference} cancelled"
    end

    private

    def set_payment
      @payment = Payment.awaiting_transfer.find(params[:id])
    end
  end
end
