require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "reserved and malformed subdomains are refused" do
    assert_not Account.new(name: "x", subdomain: "admin").valid?
    assert_not Account.new(name: "x", subdomain: "-bad-").valid?
    assert Account.new(name: "x", subdomain: "dzemat-nurnberg").valid?
  end

  test "colours must be plain hex, because they end up in a style tag" do
    account = Account.new(name: "x", subdomain: "abc", primary_color: "red;}</style><script>")

    assert_not account.valid?
    assert account.errors[:primary_color].any?
  end

  test "preset amounts parse from text and must be sensible" do
    account = Account.new(name: "x", subdomain: "abc", preset_amounts_text: "5, 7,50; 20")
    assert_equal [5, 7, 50, 20].map(&:to_d), account.preset_amounts

    account.preset_amounts_text = "5.5 10"
    assert_equal "5.5, 10", account.preset_amounts_text
    assert account.valid?

    account.preset_amounts_text = "0"
    assert_not account.valid?
    account.preset_amounts_text = "1 2 3 4 5 6 7"
    assert_not account.valid?
  end

  test "terminal text falls back to the standard wording per language" do
    account = Account.new(terminal_copy: { "de" => { "title" => "Unser Bau", "subtitle" => "" } })

    assert_equal "Unser Bau", account.terminal_text(:title, :de)
    assert_equal I18n.t("terminal.defaults.subtitle", locale: :de), account.terminal_text(:subtitle, :de)
    assert_equal "Digital donation", account.terminal_text(:title, :en)
  end
end

class AccountDestroyTest < ActiveSupport::TestCase
  test "destroying an account takes everything with it" do
    account = create_account
    terminal = create_terminal(account, connection: sumup_connection(account), provider_reader_id: "rdr_1")
    account.donations.create!(amount: 5, terminal: terminal)

    assert_difference -> { [Donation.count, Terminal.count, PaymentConnection.count, User.count].sum }, -4 do
      account.destroy!
    end
  end
end
