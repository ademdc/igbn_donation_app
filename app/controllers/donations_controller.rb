class DonationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  
  def create
    @donation = Donation.new(donation_params)
    
    if @donation.save
      begin
        sumup = SumupClient.new
        checkout = sumup.create_reader_checkout(
          amount: @donation.amount,
          currency: @donation.currency
        )
        
        @donation.update(
          checkout_id: checkout['id'],
          checkout_reference: checkout['checkout_reference'],
          status: 'processing'
        )
        
        render json: {
          success: true,
          donation_id: @donation.id,
          checkout_id: checkout['id'],
          message: 'Please complete payment on the card reader'
        }
      rescue => e
        @donation.update(status: 'failed')
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        errors: @donation.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def status
    @donation = Donation.find(params[:id])
    
    if @donation.checkout_id.present?
      begin
        sumup = SumupClient.new
        checkout = sumup.get_checkout_status(@donation.checkout_id)
        
        if checkout['status'] == 'PAID'
          @donation.update(
            status: 'paid',
            transaction_code: checkout.dig('transactions', 0, 'transaction_code')
          )
        elsif checkout['status'] == 'FAILED'
          @donation.update(status: 'failed')
        end
      rescue => e
        # Handle error
      end
    end
    
    render json: {
      id: @donation.id,
      status: @donation.status,
      amount: @donation.amount,
      currency: @donation.currency
    }
  end
  
  def reader_status
    sumup = SumupClient.new
    response = sumup.get_reader_status

    render json: response.dig('status')
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  private
  
  def donation_params
    params.require(:donation).permit(:amount, :currency, :donor_name, :donor_email)
  end
end