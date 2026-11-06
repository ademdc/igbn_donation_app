# Numbers shown on the account overview. Only completed real payments count, and only in
# the account's current currency, so amounts are never added across currencies.
class DashboardPresenter
  Day = Struct.new(:date, :total, :count, keyword_init: true)
  TerminalTotal = Struct.new(:terminal, :total, :count, :share, keyword_init: true)

  attr_reader :account, :days

  def initialize(account, days: 30)
    @account = account
    @days = days
  end

  def currency
    account.currency
  end

  def today
    received(zone.now.beginning_of_day..)
  end

  def this_month
    received(zone.now.beginning_of_month..)
  end

  def all_time
    received(nil..)
  end

  def period_total
    daily.sum(&:total)
  end

  def period_count
    daily.sum(&:count)
  end

  def average
    period_count.zero? ? 0 : period_total / period_count
  end

  # One entry per day of the period, including days without donations
  def daily
    @daily ||= begin
      day = Arel.sql("(donations.created_at AT TIME ZONE 'UTC' AT TIME ZONE #{Donation.connection.quote(zone.tzinfo.name)})::date")
      rows = donations.where(created_at: period_start..).group(day).pluck(day, Arel.sql("SUM(amount)"), Arel.sql("COUNT(*)"))
        .to_h { |date, total, count| [date, [total, count]] }
      (period_start.to_date..zone.today).map do |date|
        total, count = rows.fetch(date, [0, 0])
        Day.new(date: date, total: total, count: count)
      end
    end
  end

  def best_day_total
    daily.map(&:total).max.to_d
  end

  def by_terminal
    @by_terminal ||= begin
      totals = donations.where(created_at: period_start..).group(:terminal_id).pluck(:terminal_id, Arel.sql("SUM(amount)"), Arel.sql("COUNT(*)"))
        .to_h { |id, total, count| [id, [total, count]] }
      sum = totals.values.sum(&:first)
      account.terminals.order(:created_at).map do |terminal|
        total, count = totals.fetch(terminal.id, [0, 0])
        TerminalTotal.new(terminal: terminal, total: total, count: count, share: sum.zero? ? 0 : (total * 100 / sum).round)
      end.sort_by { |row| -row.total }
    end
  end

  def recent
    account.donations.live.includes(:terminal).recent.limit(8)
  end

  # What's left before the account takes real payments
  def setup_steps
    {
      connect: account.live_connections.any?,
      terminal: account.terminals.active.any? { |terminal| !terminal.test_mode? },
      appearance: account.image_digest(:logo).present? || account.terminal_copy.present?
    }
  end

  private

  def zone
    ActiveSupport::TimeZone[account.time_zone]
  end

  def period_start
    zone.now.beginning_of_day - (days - 1).days
  end

  def donations
    account.donations.successful.live.where(currency: currency)
  end

  def received(range)
    donations.where(created_at: range).sum(:amount)
  end
end
