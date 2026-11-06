require "test_helper"

class DashboardPresenterTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @live = create_terminal(@account, slug: "live", connection: sumup_connection(@account), provider_reader_id: "rdr_1")
    @test = create_terminal(@account, slug: "test")
  end

  def donate(amount, status: "successful", terminal: @live, at: Time.current, **attributes)
    @account.donations.create!(amount: amount, status: status, terminal: terminal, created_at: at, **attributes)
  end

  test "counts only successful real donations in the account's currency" do
    donate(10)
    donate(20, status: "failed")
    donate(40, terminal: @test)
    donate(80, currency: "CHF")
    create_terminal(other = create_account(subdomain: "other"))
    other.donations.create!(amount: 160, status: "successful")

    stats = DashboardPresenter.new(@account)

    assert_equal 10, stats.today
    assert_equal 10, stats.all_time
    assert_equal 1, stats.period_count
  end

  test "daily series has every day and buckets by the account's time zone" do
    @account.update!(time_zone: "Tokyo")
    zone = ActiveSupport::TimeZone["Tokyo"]
    donate(5, at: zone.now.beginning_of_day + 1.minute)
    donate(7, at: zone.now.beginning_of_day - 1.minute)

    stats = DashboardPresenter.new(@account, days: 7)

    assert_equal 7, stats.daily.size
    assert_equal zone.today, stats.daily.last.date
    assert_equal 5, stats.daily.last.total
    assert_equal 7, stats.daily[-2].total
    assert_equal 6, stats.average
  end

  test "terminal shares add up and include quiet terminals" do
    donate(30)
    rows = DashboardPresenter.new(@account).by_terminal

    assert_equal [@live, @test], rows.map(&:terminal)
    assert_equal [100, 0], rows.map(&:share)
  end
end
