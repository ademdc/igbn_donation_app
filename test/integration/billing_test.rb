require "test_helper"

class BillingFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  DETAILS = { billing_name: "Acme", billing_address: "Str. 1", billing_zip: "90441", billing_city: "Nürnberg",
              billing_email: "billing@acme.test", country: "DE" }.freeze

  setup do
    @account = create_account
    @terminal = create_terminal(@account)
    sign_in_to @account
  end

  test "the page renders in every language, with every plan state" do
    [{}, { trial_ends_at: 1.day.ago }, { paid_until: 6.months.from_now }, { paid_until: 1.day.ago }, { trial_ends_at: nil }].each do |state|
      @account.update!(state)
      Account::LOCALES.each do |locale|
        get "/dashboard/billing", params: { locale: locale }
        assert_response :success
        assert_no_match(/translation.missing/i, response.body)
      end
      @account.update!(trial_ends_at: 30.days.from_now, paid_until: nil)
    end
  end

  test "requesting a transfer shows the bank details and tells both sides" do
    assert_enqueued_emails 2 do
      post "/dashboard/billing", params: { kind: "subscription", extra_terminals: 0, account: DETAILS }
    end
    assert_redirected_to "/dashboard/billing#transfer"

    payment = @account.payments.last
    assert_equal 420_00, payment.amount_cents
    assert_equal "pending", payment.status

    get "/dashboard/billing"
    assert_select ".bank-details", /BA39 1610 0002 8865 0089/
    assert_select ".bank-details", /RZBABA2S/
    assert_select ".bank-details", /Hadzeli 213/
    assert_select ".bank-details", /#{payment.reference}/
  end

  test "a new request replaces the open one" do
    2.times { post "/dashboard/billing", params: { kind: "subscription", extra_terminals: 0, account: DETAILS } }

    assert_equal 1, @account.payments.awaiting_transfer.count
    assert_equal 1, @account.payments.where(status: "declined").count
  end

  test "billing details are required" do
    assert_no_difference -> { Payment.count } do
      post "/dashboard/billing", params: { kind: "subscription", account: { billing_name: "Acme" } }
    end
    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "active terminals can't be left unpaid for, whatever the form says" do
    create_terminal(@account, slug: "t2")
    create_terminal(@account, slug: "t3")

    post "/dashboard/billing", params: { kind: "subscription", extra_terminals: 0, account: DETAILS }

    assert_equal 2, @account.payments.last.extra_terminals
    assert_equal (3500 + 1000) * 12, @account.payments.last.amount_cents
  end

  test "an addon needs a paid year and at least one terminal" do
    @account.update!(paid_until: 6.months.from_now)

    post "/dashboard/billing", params: { kind: "addon", extra_terminals: 0, account: DETAILS }
    assert_redirected_to "/dashboard/billing"
    assert_equal 0, @account.payments.count

    post "/dashboard/billing", params: { kind: "addon", extra_terminals: 1, account: DETAILS }
    assert_equal "addon", @account.payments.last.kind
  end

  test "another account's payments stay out of reach" do
    other = create_account(subdomain: "other")
    Payment.subscription_for(other, user: nil, extra_terminals: 0).save!

    get "/dashboard/billing"

    assert_no_match other.payments.first.reference, response.body
  end

  test "a lapsed account sees why, keeps its dashboard, and its terminal closes" do
    @account.update!(trial_ends_at: 1.day.ago)

    get "/dashboard"
    assert_response :success
    assert_select ".flash--alert a[href='/dashboard/billing']"

    host! @terminal.hostname
    post "/donations", params: { donation: { amount: 5 } }, as: :json
    assert_response :forbidden
    get "/"
    assert_select ".kiosk__closed"
    assert_select "#donateBtn", 0
  end

  test "requesting a transfer reopens a lapsed terminal" do
    @account.update!(trial_ends_at: 1.day.ago)

    post "/dashboard/billing", params: { kind: "subscription", extra_terminals: 0, account: DETAILS }
    host! @terminal.hostname
    post "/donations", params: { donation: { amount: 5 } }, as: :json

    assert_response :success
  end

  test "a new terminal over the limit is refused with a reason" do
    @account.update!(paid_until: 1.year.from_now)

    post "/dashboard/terminals", params: { terminal: { name: "T2", slug: "t2", payment_connection_id: connect_test_mode(@account).id } }

    assert_response :unprocessable_entity
    assert_select ".errors"
  end
end

class AdminBillingTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: "correct-horse-battery", admin: true)
    @account = create_account
    @payment = Payment.subscription_for(@account, user: nil, extra_terminals: 1)
    @payment.save!
    post "/admin/login", params: { email: @admin.email, password: "correct-horse-battery" }
  end

  test "open transfers show on the overview and the account" do
    get "/admin/dashboard"
    assert_response :success
    assert_select "strong", @payment.reference

    get "/admin/accounts/#{@account.id}"
    assert_select "strong", @payment.reference
  end

  test "marking as paid activates the plan and records who did it" do
    post "/admin/payments/#{@payment.id}/confirm"

    assert @account.reload.paid?
    assert_equal "admin@example.com", @payment.reload.confirmed_by
  end

  test "cancelling leaves the plan alone, and a closed payment can't be confirmed" do
    post "/admin/payments/#{@payment.id}/cancel"
    assert_equal "declined", @payment.reload.status

    post "/admin/payments/#{@payment.id}/confirm"
    assert_response :not_found
    assert_not @account.reload.paid?
  end

  test "payments need an admin" do
    delete "/admin/logout"
    post "/admin/payments/#{@payment.id}/confirm"

    assert_redirected_to "/admin/login"
    assert_not @account.reload.paid?
  end

  test "extends a trial and filters by billing state" do
    post "/admin/accounts/#{@account.id}/extend_trial", params: { days: 10 }
    assert_in_delta 40.days.from_now, @account.reload.trial_ends_at, 60

    get "/admin/accounts", params: { status: "trialing" }
    assert_select "td a", "Acme"
    get "/admin/accounts", params: { status: "paying" }
    assert_select "td a", 0
  end
end

class TenantBillingIsolationTest < ActionDispatch::IntegrationTest
  test "an owner can't confirm a payment, on any host" do
    account = create_account
    payment = Payment.subscription_for(account, user: nil, extra_terminals: 0)
    payment.save!
    sign_in_to account

    post "/admin/payments/#{payment.id}/confirm"
    assert_response :not_found

    host! "localhost"
    post "/admin/payments/#{payment.id}/confirm"
    assert_redirected_to "/admin/login"
    assert_not account.reload.paid?
  end
end
