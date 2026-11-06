require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    connect_test_mode(@account)
    sign_in_to @account
  end

  test "needs a login" do
    delete "/logout"
    get "/dashboard"

    assert_redirected_to "/login"
  end

  test "every page renders in every language" do
    terminal = create_terminal(@account)
    @account.donations.create!(amount: 5, terminal: terminal, status: "successful")
    sumup_connection(@account)

    Account::LOCALES.each do |locale|
      ["/dashboard", "/dashboard?days=7", "/dashboard/donations", "/dashboard/terminals", "/dashboard/terminals/new",
       "/dashboard/terminals/#{terminal.id}/edit", "/dashboard/appearance", "/dashboard/payments", "/dashboard/payments/sumup/edit"].each do |path|
        get path, params: { locale: locale }
        assert_response :success, path
        assert_no_match "translation missing", response.body.downcase, path
        assert_no_match(/class="translation_missing"/, response.body, path)
      end
    end
  end

  test "saves appearance and shows it in the preview form" do
    patch "/dashboard/appearance", params: { account: {
      primary_color: "#112233", preset_amounts_text: "3, 6", currency: "CHF", locales: ["", "bs", "de"],
      allow_custom_amount: "0", terminal_copy: { de: { title: "Neuer Titel", subtitle: "Unter", thank_you: "" } }
    } }

    assert_redirected_to "/dashboard/appearance"
    @account.reload
    assert_equal "#112233", @account.primary_color
    assert_equal [3, 6], @account.preset_amounts.map(&:to_i)
    assert_equal %w[bs de], @account.locales
    assert_equal "CHF", @account.currency
    assert_not @account.allow_custom_amount?
    assert_equal "Neuer Titel", @account.terminal_text(:title, :de)
  end

  test "refuses bad appearance values" do
    patch "/dashboard/appearance", params: { account: { primary_color: "red", locales: [""] } }

    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "accepts a real image and refuses anything else" do
    png = Rack::Test::UploadedFile.new(StringIO.new("\x89PNG\r\n\x1A\n1234".b), "image/png", true, original_filename: "logo.png")
    patch "/dashboard/appearance", params: { account: { logo: png } }
    assert_redirected_to "/dashboard/appearance"
    assert_equal "image/png", @account.brand_images.find_by(kind: "logo").content_type

    svg = Rack::Test::UploadedFile.new(StringIO.new("<svg onload='alert(1)'/>"), "image/png", original_filename: "x.png")
    patch "/dashboard/appearance", params: { account: { background: svg } }
    assert_response :unprocessable_entity
    assert_nil @account.brand_images.find_by(kind: "background")

    delete "/dashboard/appearance/images/logo"
    assert_nil @account.brand_images.find_by(kind: "logo")
  end

  test "connecting SumUp checks the keys, and never echoes them" do
    stub_request(:get, %r{/readers}).to_return(status: 401, body: "{}")
    patch "/dashboard/payments/sumup", params: { credentials: { api_key: "sup_sk_abcdefgh5678", merchant_code: "MK01A8C2" } }
    assert_response :unprocessable_entity
    assert_select ".errors"

    stub_request(:get, %r{/readers}).to_return(body: { items: [] }.to_json)
    patch "/dashboard/payments/sumup", params: { credentials: { api_key: "sup_sk_abcdefgh5678", merchant_code: "MK01A8C2" } }
    assert_redirected_to "/dashboard/payments"
    assert @account.payment_connections.find_by(provider: "sumup").verified_at

    get "/dashboard/payments/sumup/edit"
    assert_no_match "sup_sk_abcdefgh5678", response.body
    assert_match "••••5678", response.body
  end

  test "a connection in use can't be removed" do
    connection = sumup_connection(@account)
    create_terminal(@account, connection: connection, provider_reader_id: "rdr_1")

    delete "/dashboard/payments/sumup"

    assert_equal I18n.t("app.payments.in_use", locale: :de), flash[:alert]
    assert PaymentConnection.exists?(connection.id)
  end

  test "adds a terminal by pairing a reader" do
    sumup = sumup_connection(@account)
    stub_request(:post, %r{/readers}).to_return(status: 201, body: { id: "rdr_new" }.to_json)

    post "/dashboard/terminals", params: { terminal: { name: "Eingang", slug: "eingang", payment_connection_id: sumup.id, pairing_code: "ABCD1234" } }

    assert_redirected_to "/dashboard/terminals"
    terminal = @account.terminals.find_by(slug: "eingang")
    assert_equal "rdr_new", terminal.provider_reader_id
    assert_equal "eingang.acme.localhost", terminal.hostname
  end

  test "the terminal form says where the keys go until a provider is connected" do
    get "/dashboard/terminals/new"
    assert_select "a[href='/dashboard/payments']", /SumUp/

    sumup_connection(@account)
    get "/dashboard/terminals/new"
    assert_select ".flash a", 0
  end

  test "the address of a terminal can't be changed" do
    terminal = create_terminal(@account)

    patch "/dashboard/terminals/#{terminal.id}", params: { terminal: { slug: "other", name: "Renamed" } }

    assert_equal "terminal1.acme.localhost", terminal.reload.hostname
    assert_equal "Renamed", terminal.name
  end

  test "a password reset works once" do
    delete "/logout"
    user = @account.users.first
    post "/password_resets", params: { email: user.email }
    token = user.generate_token_for(:password_reset)

    patch "/password_resets/#{token}", params: { user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" } }
    assert_redirected_to "/dashboard"
    assert user.reload.authenticate("a-brand-new-password")

    patch "/password_resets/#{token}", params: { user: { password: "yet-another-password", password_confirmation: "yet-another-password" } }
    assert_redirected_to "/password_resets/new"
  end
end
