require "test_helper"

class DonationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @account = create_account
    @terminal = create_terminal(@account, connection: sumup_connection(@account), provider_reader_id: "rdr_1")
  end

  test "takes its currency from the account and marks test terminals" do
    @account.update!(currency: "CHF")
    test_terminal = create_terminal(@account, slug: "t2")

    donation = @account.donations.create!(amount: 5, terminal: test_terminal)

    assert_equal "CHF", donation.currency
    assert donation.test?
    assert_not @account.donations.create!(amount: 5, terminal: @terminal).test?
  end

  test "a refused checkout fails the donation and re-raises" do
    stub_request(:post, %r{/checkout}).to_return(status: 422, body: { errors: { type: "READER_BUSY" } }.to_json)
    donation = @account.donations.create!(amount: 5, terminal: @terminal)

    assert_raises(PaymentProviders::Error) { donation.start_checkout! }
    assert_equal "failed", donation.reload.status
  end

  test "sync emails once, however many times it runs" do
    stub_request(:get, %r{/transactions}).to_return(body: { status: "SUCCESSFUL", transaction_code: "TX1" }.to_json)
    donation = @account.donations.create!(amount: 5, terminal: @terminal, status: "processing", checkout_id: "ctx_1", donor_email: "d@example.com")

    assert_enqueued_emails 1 do
      donation.sync_with_provider
      donation.sync_with_provider
      Donation.find(donation.id).sync_with_provider
    end
    assert_equal "TX1", donation.reload.transaction_code
  end

  test "pending leaves the donation processing" do
    stub_request(:get, %r{/transactions}).to_return(status: 404, body: "{}")
    donation = @account.donations.create!(amount: 5, terminal: @terminal, status: "processing", checkout_id: "ctx_1")

    donation.sync_with_provider

    assert_equal "processing", donation.reload.status
  end

  test "a final status never changes" do
    donation = @account.donations.create!(amount: 5, terminal: @terminal, status: "successful")

    donation.apply("failed")

    assert_equal "successful", donation.reload.status
  end
end
