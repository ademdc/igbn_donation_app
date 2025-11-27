class DonationMailer < ApplicationMailer
  def confirmation_email(donation)
    @donation = donation

    mail(
      to: @donation.donor_email,
      subject: 'Hvala na Vasoj donaciji!'
    )
  end
end
