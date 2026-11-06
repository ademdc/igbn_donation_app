require "test_helper"

class BillingRemindersTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup { @account = create_account }

  test "reminds at each stage of the trial, once" do
    @account.update!(trial_ends_at: 14.days.from_now)

    assert_enqueued_emails(1) { assert_equal 1, Billing::Reminders.run }
    assert_enqueued_emails(0) { assert_equal 0, Billing::Reminders.run }

    travel_to 11.days.from_now do
      assert_enqueued_emails(1) { Billing::Reminders.run }
    end
  end

  test "stays quiet before the first stage" do
    assert_equal 0, Billing::Reminders.run
  end

  test "reminds before the paid year ends" do
    @account.update!(paid_until: 7.days.from_now)

    assert_enqueued_emails(1) { Billing::Reminders.run }
  end

  test "stays quiet once a transfer is on its way, and for suspended accounts" do
    @account.update!(trial_ends_at: 3.days.from_now)
    Payment.subscription_for(@account, user: nil, extra_terminals: 0).save!
    assert_equal 0, Billing::Reminders.run

    @account.payments.delete_all
    @account.update!(status: "suspended")
    assert_equal 0, Billing::Reminders.run
  end

  test "free accounts are never reminded" do
    @account.update!(trial_ends_at: nil)

    assert_equal 0, Billing::Reminders.run
  end
end
