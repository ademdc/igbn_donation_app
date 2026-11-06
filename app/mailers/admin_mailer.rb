# Notes for the people running the service, sent to ADMIN_EMAIL
class AdminMailer < ApplicationMailer
  def bank_transfer_requested
    @payment = params[:payment]
    @account = @payment.account
    mail to: Rails.configuration.x.admin_email,
         subject: "Bank transfer expected: #{@payment.reference}, #{@account.name}"
  end
end
