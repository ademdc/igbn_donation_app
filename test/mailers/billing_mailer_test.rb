require "test_helper"

class BillingMailerTest < ActionMailer::TestCase
  setup do
    @account = create_account
    @user = @account.owner
    @payment = Payment.subscription_for(@account, user: @user, extra_terminals: 0)
    @payment.save!
  end

  test "every billing email renders in every language" do
    Account::LOCALES.each do |locale|
      @user.update!(locale: locale)
      mails = [
        AccountMailer.with(payment: @payment, user: @user).bank_transfer,
        AccountMailer.with(user: @user, kind: "trial", days_left: 3, deadline: 3.days.from_now.to_date).reminder,
        AccountMailer.with(user: @user, kind: "renewal", days_left: 1, deadline: 1.day.from_now.to_date).reminder
      ]
      mails.each do |mail|
        assert_no_match(/translation.missing/i, mail.subject + mail.html_part.body.to_s + mail.text_part.body.to_s)
      end
    end
  end

  test "the transfer email carries everything needed to pay" do
    body = AccountMailer.with(payment: @payment, user: @user).bank_transfer.text_part.body.to_s

    ["BA39 1610 0002 8865 0089", "RZBABA2S", "Everline d.o.o.", "Hadzeli 213", "420", @payment.reference].each do |detail|
      assert_match detail, body
    end
  end

  test "the confirmation names the new end date" do
    @payment.approve!(confirmed_by: "x")

    mail = AccountMailer.with(payment: @payment, user: @user).payment_confirmed

    assert_match @payment.reference, mail.subject
    assert_match "420", mail.text_part.body.to_s
  end

  test "the admin notice links to the account" do
    mail = AdminMailer.with(payment: @payment, locale: "en").bank_transfer_requested

    assert_equal [Rails.configuration.x.admin_email], mail.to
    assert_match "/admin/accounts/#{@account.id}", mail.body.to_s
  end
end
