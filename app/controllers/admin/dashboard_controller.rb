module Admin
  class DashboardController < BaseController
    def index
      @accounts_total = Account.count
      @accounts_suspended = Account.suspended.count
      @signups_30_days = Account.where(created_at: 30.days.ago..).count
      @terminals_total = Terminal.active.count
      # Money isn't converted: each currency is shown on its own
      @volume_30_days = Donation.successful.live.where(created_at: 30.days.ago..).group(:currency).sum(:amount)
      @donations_30_days = Donation.successful.live.where(created_at: 30.days.ago..).count
      @awaiting_provider = Account.active.where.missing(:payment_connections).or(
        Account.active.where.not(id: PaymentConnection.where.not(provider: PaymentProviders::TestMode.key).select(:account_id))
      ).count
      @recent_accounts = Account.order(created_at: :desc).limit(8)
      @top_accounts = Account.joins(:donations).merge(Donation.successful.live.where(created_at: 30.days.ago..))
        .group("accounts.id").select("accounts.*, COUNT(donations.id) AS donation_count").order("donation_count DESC").limit(8)
      @failing_terminals = Terminal.includes(:account).where(certificate_status: "failed")
    end
  end
end
