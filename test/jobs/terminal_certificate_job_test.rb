require "test_helper"

class TerminalCertificateJobTest < ActiveJob::TestCase
  setup do
    ENV["FLY_API_TOKEN"] = "token"
    ENV["FLY_APP_NAME"] = "digital-donation"
    @terminal = create_terminal(create_account)
    @add = "https://api.machines.dev/v1/apps/digital-donation/certificates/acme"
  end

  teardown do
    ENV.delete("FLY_API_TOKEN")
    ENV.delete("FLY_APP_NAME")
  end

  test "new terminals wait for a certificate when running on Fly" do
    assert_equal "pending", @terminal.certificate_status
    assert_not @terminal.live?
    assert_enqueued_with(job: TerminalCertificateJob) { create_terminal(@terminal.account, slug: "t2") }
  end

  test "goes live once Fly has issued the certificate" do
    stub_request(:post, @add).with(body: { hostname: @terminal.hostname }).to_return(body: { status: "Ready" }.to_json)

    TerminalCertificateJob.perform_now(@terminal)

    assert_equal "issued", @terminal.reload.certificate_status
    assert @terminal.live?
  end

  test "checks again while the certificate is on its way" do
    stub_request(:post, @add).to_return(status: 409, body: { error: "exists" }.to_json)
    stub_request(:post, %r{/certificates/#{@terminal.hostname}/check}).to_return(body: { status: "pending" }.to_json)

    assert_enqueued_with(job: TerminalCertificateJob, args: [@terminal, 2]) do
      TerminalCertificateJob.perform_now(@terminal)
    end
    assert_equal "pending", @terminal.reload.certificate_status
  end

  test "gives up after enough attempts" do
    stub_request(:post, @add).to_return(body: { status: "pending" }.to_json)

    TerminalCertificateJob.perform_now(@terminal, TerminalCertificateJob::MAX_ATTEMPTS)

    assert_equal "failed", @terminal.reload.certificate_status
  end
end
