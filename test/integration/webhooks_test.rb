require "test_helper"

class WebhooksTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    @account = create_account
    @connection = sumup_connection(@account)
    @terminal = create_terminal(@account, connection: @connection, provider_reader_id: "rdr_1")
    @donation = @account.donations.create!(amount: 5, terminal: @terminal, status: "processing", checkout_id: "ctx_1")
  end

  def deliver(status, connection: @connection, checkout_id: "ctx_1", token: connection.webhook_token)
    post "/webhooks/sumup/#{token}", params: {
      id: "1", event_type: "solo.transaction.updated", timestamp: "2026-11-06T10:00:00Z",
      payload: { client_transaction_id: checkout_id, merchant_code: "MK01A8C2", status: status }
    }.to_json, headers: { "Content-Type" => "application/json" }
  end

  test "a success is confirmed with the provider before it counts" do
    stub = stub_request(:get, %r{/transactions}).to_return(body: { status: "SUCCESSFUL", transaction_code: "TX1" }.to_json)

    deliver "successful"

    assert_response :ok
    assert_requested stub
    assert_equal "successful", @donation.reload.status
  end

  test "a forged success doesn't count if the provider disagrees" do
    stub_request(:get, %r{/transactions}).to_return(status: 404, body: "{}")

    deliver "successful"

    assert_equal "processing", @donation.reload.status
  end

  test "a failure applies directly" do
    deliver "failed"

    assert_response :ok
    assert_equal "failed", @donation.reload.status
  end

  test "a wrong token changes nothing" do
    deliver "failed", token: "wrong"

    assert_response :not_found
    assert_equal "processing", @donation.reload.status
  end

  test "another account's token can't touch this donation" do
    other = create_account(subdomain: "other")

    deliver "failed", connection: sumup_connection(other)

    assert_response :ok
    assert_equal "processing", @donation.reload.status
  end

  test "asks the provider to retry when the lookup fails" do
    stub_request(:get, %r{/transactions}).to_return(status: 500, body: "{}")

    deliver "successful"

    assert_response :service_unavailable
  end

  test "ignores unknown events and rejects bad JSON" do
    post "/webhooks/sumup/#{@connection.webhook_token}", params: { event_type: "OTHER" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :ok

    post "/webhooks/sumup/#{@connection.webhook_token}", params: "not json", headers: { "Content-Type" => "text/plain" }
    assert_response :bad_request
  end
end
