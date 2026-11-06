require "test_helper"

class TerminalTest < ActiveSupport::TestCase
  setup { @account = create_account }

  test "nested hostname by default" do
    terminal = create_terminal(@account)

    assert_equal "terminal1.acme.localhost", terminal.hostname
    assert_equal terminal, Terminal.for_host("TERMINAL1.acme.localhost")
  end

  test "flat hostname as the fallback, which can't clash with an account" do
    Rails.configuration.x.terminal_hosts = "flat"
    create_account(subdomain: "kasse-acme")

    assert_equal "terminal1-acme.localhost", create_terminal(@account).hostname
    terminal = @account.terminals.new(name: "x", slug: "kasse", payment_connection: connect_test_mode(@account))
    assert_not terminal.valid?
    assert terminal.errors[:slug].any?
  ensure
    Rails.configuration.x.terminal_hosts = "nested"
  end

  test "slug is unique per account, not globally" do
    create_terminal(@account)
    other = create_account(subdomain: "other")

    assert_equal "terminal1.other.localhost", create_terminal(other).hostname
    assert_not @account.terminals.new(name: "x", slug: "terminal1", payment_connection: connect_test_mode(@account)).valid?
  end

  test "a live provider needs a reader, test mode doesn't" do
    connection = sumup_connection(@account)

    assert_not @account.terminals.new(name: "x", slug: "a", payment_connection: connection).valid?
    assert @account.terminals.new(name: "x", slug: "a", payment_connection: connection, provider_reader_id: "rdr_1").valid?
    assert @account.terminals.new(name: "x", slug: "a", payment_connection: connection, pairing_code: "ABCD1234").valid?
    assert @account.terminals.new(name: "x", slug: "a", payment_connection: connect_test_mode(@account)).valid?
  end

  test "can't use another account's connection" do
    other = create_account(subdomain: "other")
    terminal = @account.terminals.new(name: "x", slug: "a", payment_connection: connect_test_mode(other))

    assert_not terminal.valid?
  end

  test "pairing stores the provider's reader id" do
    stub_request(:post, %r{/readers}).to_return(status: 201, body: { id: "rdr_new" }.to_json)
    terminal = @account.terminals.new(name: "x", slug: "a", payment_connection: sumup_connection(@account), pairing_code: "ABCD1234")

    assert terminal.save_with_pairing
    assert_equal "rdr_new", terminal.reload.provider_reader_id
  end

  test "a wrong pairing code becomes a form error" do
    stub_request(:post, %r{/readers}).to_return(status: 404, body: "{}")
    terminal = @account.terminals.new(name: "x", slug: "a", payment_connection: sumup_connection(@account), pairing_code: "WRONG")

    assert_not terminal.save_with_pairing
    assert terminal.errors[:pairing_code].any?
    assert_not terminal.persisted?
  end

  test "a terminal with donations can't be deleted" do
    terminal = create_terminal(@account)
    @account.donations.create!(amount: 5, terminal: terminal)

    assert_not terminal.destroy
  end
end
