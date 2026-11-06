require "test_helper"

class BillingTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup { @account = create_account }

  test "a new account gets 30 days and takes donations" do
    assert_in_delta 30.days.from_now, @account.trial_ends_at, 5
    assert @account.trial?
    assert_equal 30, @account.trial_days_left
    assert @account.taking_donations?
  end

  test "terminals pause when the trial ends, and the account is otherwise untouched" do
    @account.update!(trial_ends_at: 1.minute.ago)

    assert @account.trial_expired?
    assert_equal "trial_expired", @account.display_status
    assert_not @account.taking_donations?
    assert @account.active?
  end

  test "terminals pause when the paid year ends" do
    @account.update!(paid_until: 1.minute.ago)

    assert_equal "payment_due", @account.display_status
    assert_not @account.taking_donations?
  end

  test "a transfer on its way keeps terminals running, but not forever" do
    @account.update!(trial_ends_at: 1.minute.ago)
    payment = Payment.subscription_for(@account, user: nil, extra_terminals: 0)
    payment.save!

    assert @account.taking_donations?

    payment.update!(created_at: (Account::TRANSFER_GRACE + 1.day).ago)
    assert_not @account.taking_donations?
  end

  test "an account without dates is free of charge and never lapses" do
    @account.update!(trial_ends_at: nil)

    assert @account.free_of_charge?
    assert @account.taking_donations?
    assert_nil @account.terminal_limit
  end

  test "suspending beats everything" do
    @account.update!(status: "suspended", paid_until: 1.year.from_now)

    assert_not @account.taking_donations?
  end

  test "a year costs 12 months of the base price plus extra terminals" do
    payment = Payment.subscription_for(@account, user: nil, extra_terminals: 2)

    assert_equal (3500 + 2 * 500) * 12, payment.amount_cents
    assert_equal 420_00, Payment.subscription_for(@account, user: nil, extra_terminals: 0).amount_cents
  end

  test "paying during the trial doesn't lose the remaining days" do
    @account.update!(trial_ends_at: 10.days.from_now)

    payment = Payment.subscription_for(@account, user: nil, extra_terminals: 0)

    assert_in_delta 10.days.from_now, payment.period_start, 5
    assert_in_delta 10.days.from_now + 1.year, payment.period_end, 5
  end

  test "renewing extends from the end of the paid year" do
    @account.update!(paid_until: 2.months.from_now)

    payment = Payment.subscription_for(@account, user: nil, extra_terminals: 0)

    assert_in_delta 2.months.from_now + 1.year, payment.period_end, 5
  end

  test "extra terminals during the year are charged per started month" do
    @account.update!(paid_until: 3.months.from_now - 1.day)

    payment = Payment.addon_for(@account, user: nil, extra_terminals: 2)

    assert_equal 2 * 500 * 3, payment.amount_cents
  end

  test "approving activates the plan once and tells the owner once" do
    payment = Payment.subscription_for(@account, user: nil, extra_terminals: 1)
    payment.save!

    assert_enqueued_emails 1 do
      payment.approve!(confirmed_by: "admin@example.com")
      Payment.find(payment.id).approve!(confirmed_by: "admin@example.com")
    end

    @account.reload
    assert @account.paid?
    assert_equal 1, @account.extra_terminals
    assert_equal "admin@example.com", payment.reload.confirmed_by
  end

  test "an addon adds to the extra terminals" do
    @account.update!(paid_until: 6.months.from_now, extra_terminals: 1)
    payment = Payment.addon_for(@account, user: nil, extra_terminals: 2)
    payment.save!

    payment.approve!(confirmed_by: "x")

    assert_equal 3, @account.reload.extra_terminals
  end

  test "a declined payment can't be approved" do
    payment = Payment.subscription_for(@account, user: nil, extra_terminals: 0)
    payment.save!
    payment.decline!

    payment.approve!(confirmed_by: "x")

    assert_equal "declined", payment.reload.status
    assert_not @account.reload.paid?
  end

  test "terminals are unlimited in the trial and limited to what's paid for" do
    create_terminal(@account)
    create_terminal(@account, slug: "t2")
    assert_equal 1, @account.extra_terminals_needed

    @account.update!(paid_until: 1.year.from_now)
    third = @account.terminals.new(name: "x", slug: "t3", payment_connection: connect_test_mode(@account))
    assert_not third.valid?
    assert_match "Terminal", third.errors[:base].first

    @account.update!(extra_terminals: 2)
    assert third.valid?
  end

  test "a turned-off terminal doesn't count, and can't come back over the limit" do
    create_terminal(@account)
    spare = create_terminal(@account, slug: "t2")
    spare.update!(active: false)
    @account.update!(paid_until: 1.year.from_now)

    assert_equal 0, @account.extra_terminals_needed
    assert_not spare.update(active: true)
  end
end
