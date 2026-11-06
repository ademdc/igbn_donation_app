# The public donation terminal. Everything is scoped to the terminal the host belongs to.
class DonationsController < ApplicationController
  layout "terminal"

  before_action :set_terminal
  around_action :switch_locale
  before_action :require_open_terminal, only: :create

  def new
    @recent_donations = @account.donations.successful.live.recent.limit(5) if @account.show_recent_donations?
  end

  def create
    @donation = @account.donations.new(donation_params.merge(terminal: @terminal, locale: I18n.locale.to_s))

    unless allowed_amount?(@donation.amount)
      return render json: { success: false, error: t("terminal.errors.invalid_amount") }, status: :unprocessable_entity
    end

    if @donation.save
      @donation.start_checkout!
      render json: { success: true, donation_id: @donation.id }
    else
      render json: { success: false, error: @donation.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue PaymentProviders::Error => e
    Rails.logger.warn "Checkout failed on #{@terminal.hostname}: #{e.message}"
    render json: { success: false, error: t("payment_errors.#{e.code}", default: t("payment_errors.provider_error")) }, status: :unprocessable_entity
  end

  def status
    donation = @terminal.donations.find(params[:id])

    begin
      donation.sync_with_provider
    rescue PaymentProviders::Error => e
      # The webhook or the next poll will settle it
      Rails.logger.warn "Status check failed for donation #{donation.id}: #{e.message}"
    end

    render json: { id: donation.id, status: donation.status, amount: donation.amount.to_f, currency: donation.currency }
  end

  def reader_status
    status = @terminal.client.reader_status(@terminal.provider_reader_id)
    render json: { online: status.online, state: status.state }
  rescue PaymentProviders::Error => e
    render json: { error: e.code }, status: :unprocessable_entity
  end

  private

  def set_terminal
    @terminal = Current.terminal = request.env.fetch("app.terminal")
    @account = Current.account = @terminal.account
  end

  def switch_locale(&action)
    locale = params[:locale].presence_in(@account.locales) || @account.default_locale
    I18n.with_locale(locale, &action)
  end

  def require_open_terminal
    return if @terminal.active? && @account.taking_donations?
    render json: { success: false, error: t("terminal.closed") }, status: :forbidden
  end

  def allowed_amount?(amount)
    @account.allow_custom_amount? || amount.in?(@account.preset_amounts)
  end

  def donation_params
    fields = @account.collect_donor_details? ? [:amount, :donor_name, :donor_email] : [:amount]
    params.require(:donation).permit(*fields)
  end
end
