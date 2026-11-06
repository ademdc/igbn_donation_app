require "test_helper"

class TerminalPageTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @account = create_account
    @terminal = create_terminal(@account)
    host! @terminal.hostname
  end

  def donate(amount, **fields)
    post "/donations", params: { donation: { amount: amount, **fields } }, as: :json
  end

  test "shows the account's branding and wording" do
    @account.update!(primary_color: "#112233", preset_amounts: [7, 14], terminal_copy: { "bs" => { "title" => "Naša džamija" } }, locales: %w[bs de])

    get "/"

    assert_response :success
    assert_select "h1", "Naša džamija"
    assert_select "style", /--primary: #112233/
    assert_select ".preset-amount-btn", 2
    assert_select ".kiosk__test"
  end

  test "language switch stays within the account's languages" do
    @account.update!(locales: %w[de en])

    get "/", params: { locale: "en" }
    assert_select "#donateBtn", "Donate now"
    get "/", params: { locale: "bs" }
    assert_select "#donateBtn", "Jetzt spenden"
  end

  test "a full test payment" do
    donate 10, donor_name: "A"
    assert_response :success
    donation = Donation.find(response.parsed_body["donation_id"])
    assert_equal @terminal, donation.terminal
    assert donation.test?
    assert_equal "processing", donation.status

    get "/donations/#{donation.id}/status"
    assert_equal "processing", response.parsed_body["status"]

    travel PaymentProviders::TestMode::APPROVAL_SECONDS + 1 do
      get "/donations/#{donation.id}/status"
    end
    assert_equal "successful", response.parsed_body["status"]
  end

  test "ignores a currency sent by the browser" do
    post "/donations", params: { donation: { amount: 5, currency: "USD" } }, as: :json

    assert_equal "EUR", Donation.last.currency
  end

  test "custom amounts can be turned off on the server" do
    @account.update!(allow_custom_amount: false, preset_amounts: [5])

    donate 99
    assert_response :unprocessable_entity
    donate 5
    assert_response :success
  end

  test "donor details are dropped when the account doesn't collect them" do
    @account.update!(collect_donor_details: false)

    donate 5, donor_name: "A", donor_email: "a@example.com"

    assert_nil Donation.last.donor_name
    assert_nil Donation.last.donor_email
  end

  test "refuses donations on a turned-off terminal and a suspended account" do
    @terminal.update!(active: false)
    donate 5
    assert_response :forbidden

    @terminal.update!(active: true)
    @account.update!(status: "suspended")
    donate 5
    assert_response :forbidden

    get "/"
    assert_select ".kiosk__closed"
  end

  test "reader errors reach the donor translated" do
    terminal = create_terminal(@account, slug: "live", connection: sumup_connection(@account), provider_reader_id: "rdr_1")
    stub_request(:post, %r{/checkout}).to_return(status: 422, body: { errors: { type: "READER_OFFLINE" } }.to_json)
    host! terminal.hostname

    post "/donations?locale=en", params: { donation: { amount: 5 } }, as: :json

    assert_response :unprocessable_entity
    assert_match "offline", response.parsed_body["error"]
    assert_equal "failed", Donation.last.status
  end

  test "reader status is normalised" do
    get "/reader_status"
    assert_equal({ "online" => true, "state" => "IDLE" }, response.parsed_body)
  end

  test "recent donations only show when turned on, and never test ones" do
    live = create_terminal(@account, slug: "live", connection: sumup_connection(@account), provider_reader_id: "rdr_1")
    @account.donations.create!(amount: 5, terminal: live, status: "successful", donor_name: "Real")
    @account.donations.create!(amount: 5, terminal: @terminal, status: "successful", donor_name: "Fake")

    get "/"
    assert_select ".kiosk__recent", 0

    @account.update!(show_recent_donations: true)
    get "/"
    assert_select ".kiosk__recent li", 1
    assert_select ".kiosk__recent", /Real/
  end

  test "unknown hosts are not found" do
    host! "nope.acme.localhost"
    get "/dashboard"
    assert_response :not_found
  end
end
