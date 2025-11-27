class Donation < ApplicationRecord
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: %w[pending processing successful failed cancelled] }

  before_validation :set_defaults, on: :create
  
  after_create :send_confirmation_email 

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'successful') }
  
  def self.preset_amounts
    [5, 10, 20]
  end
  
  def pending?
    status == 'pending'
  end

  def successful?
    status == 'successful'
  end
  
  private
  
  def set_defaults
    self.status ||= 'pending'
    self.currency ||= 'EUR'
  end

  private

  def send_confirmation_email
    if self.donor_email.present? && self.successful?
      DonationMailer.confirmation_email(self).deliver
    end
  end
end