class HomeController < ApplicationController
  def index
      @preset_amounts = Donation.preset_amounts
      @recent_donations = Donation.successful.recent.limit(10)
  end
end
