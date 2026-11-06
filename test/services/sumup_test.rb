require "test_helper"

class SumupTest < ActiveSupport::TestCase
  API = "https://api.sumup.com"

  setup do
    @client = PaymentProviders::Sumup.new("api_key" => "key", "merchant_code" => "MK01A8C2",
                                          "affiliate_key" => "aff", "affiliate_app_id" => "org.acme")
  end

  test "creates a checkout in minor units with affiliate and return url" do
    stub = stub_request(:post, "#{API}/v0.1/merchants/MK01A8C2/readers/rdr_1/checkout")
      .with(headers: { "Authorization" => "Bearer key" }, body: {
        total_amount: { value: 1999, currency: "EUR", minor_unit: 2 }, description: "Acme #1",
        return_url: "https://domain.test/webhooks/sumup/abc", affiliate: { app_id: "org.acme", key: "aff" }
      }).to_return(status: 201, body: { data: { client_transaction_id: "ctx_1", checkout_id: "chk_1" } }.to_json)

    id = @client.create_checkout(amount: 19.99.to_d, currency: "EUR", reader_id: "rdr_1", description: "Acme #1",
                                 webhook_url: "https://domain.test/webhooks/sumup/abc")

    assert_equal "ctx_1", id
    assert_requested stub
  end

  test "leaves out a non-https return url, which SumUp would reject" do
    stub = stub_request(:post, %r{/checkout}).with { |request| !JSON.parse(request.body).key?("return_url") }
      .to_return(status: 201, body: { data: { client_transaction_id: "ctx_1" } }.to_json)

    @client.create_checkout(amount: 5.to_d, currency: "EUR", reader_id: "rdr_1", description: "x", webhook_url: "http://acme.localhost/x")

    assert_requested stub
  end

  test "maps reader errors to codes the terminal can translate" do
    stub_request(:post, %r{/checkout}).to_return(status: 422, body: { errors: { type: "READER_OFFLINE", detail: "The device is offline." } }.to_json)

    error = assert_raises(PaymentProviders::Error) do
      @client.create_checkout(amount: 5.to_d, currency: "EUR", reader_id: "rdr_1", description: "x", webhook_url: "https://x")
    end
    assert_equal :reader_offline, error.code
  end

  test "looks the outcome up by client transaction id on the v2.1 endpoint" do
    stub_request(:get, "#{API}/v2.1/merchants/MK01A8C2/transactions?client_transaction_id=ctx_1")
      .to_return(body: { status: "SUCCESSFUL", transaction_code: "TX1" }.to_json)

    result = @client.checkout_status("ctx_1")

    assert_equal "successful", result.state
    assert_equal "TX1", result.transaction_code
  end

  test "a transaction SumUp doesn't know yet is pending" do
    stub_request(:get, %r{/transactions}).to_return(status: 404, body: { error_code: "NOT_FOUND" }.to_json)

    assert_equal "pending", @client.checkout_status("ctx_1").state
  end

  test "reads reader status from the status endpoint" do
    stub_request(:get, "#{API}/v0.1/merchants/MK01A8C2/readers/rdr_1/status")
      .to_return(body: { data: { status: "ONLINE", state: "IDLE" } }.to_json)

    status = @client.reader_status("rdr_1")

    assert status.online
    assert_equal "IDLE", status.state
  end

  test "pairs a reader from its code" do
    stub_request(:post, "#{API}/v0.1/merchants/MK01A8C2/readers")
      .with(body: { pairing_code: "4WLFDSBF", name: "Front" }).to_return(status: 201, body: { id: "rdr_new" }.to_json)

    assert_equal "rdr_new", @client.pair_reader(code: " 4WLFDSBF ", name: "Front")
  end

  test "rejected credentials raise unauthorized" do
    stub_request(:get, "#{API}/v0.1/merchants/MK01A8C2/readers").to_return(status: 401, body: "{}")

    error = assert_raises(PaymentProviders::Error) { @client.verify }
    assert_equal :unauthorized, error.code
  end

  test "understands only the reader webhook" do
    event = @client.parse_webhook("event_type" => "solo.transaction.updated", "payload" => { "client_transaction_id" => "ctx_1", "status" => "successful" })

    assert_equal "ctx_1", event.checkout_id
    assert_equal "successful", event.state
    assert_nil @client.parse_webhook("event_type" => "CHECKOUT_STATUS_CHANGED")
  end
end
