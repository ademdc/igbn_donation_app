require "test_helper"

class TenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @acme = create_account
    @other = create_account(subdomain: "other")
    @acme_terminal = create_terminal(@acme)
    @other_terminal = create_terminal(@other)
  end

  test "a donation can't be read through another account's terminal" do
    donation = @other.donations.create!(amount: 5, terminal: @other_terminal)
    host! @acme_terminal.hostname

    get "/donations/#{donation.id}/status"

    assert_response :not_found
  end

  test "a donation can't be read through a sibling terminal" do
    sibling = create_terminal(@acme, slug: "t2")
    donation = @acme.donations.create!(amount: 5, terminal: sibling)
    host! @acme_terminal.hostname

    get "/donations/#{donation.id}/status"

    assert_response :not_found
  end

  test "a session doesn't carry over to another account" do
    sign_in_to @acme
    assert_redirected_to "/dashboard"

    host! @other.host
    get "/dashboard"

    assert_redirected_to "/login"
  end

  test "an account's password doesn't open another account" do
    host! @other.host
    post "/login", params: { email: @acme.users.first.email, password: "correct-horse-battery" }

    assert_response :unprocessable_entity
  end

  test "dashboard records of another account are out of reach" do
    sign_in_to @acme

    get "/dashboard/terminals/#{@other_terminal.id}/edit"
    assert_response :not_found

    patch "/dashboard/terminals/#{@other_terminal.id}", params: { terminal: { name: "hacked" } }
    assert_response :not_found
    assert_equal "terminal1", @other_terminal.reload.name

    delete "/dashboard/terminals/#{@other_terminal.id}"
    assert_response :not_found
    assert Terminal.exists?(@other_terminal.id)
  end

  test "a terminal can't be pointed at another account's connection" do
    sign_in_to @acme

    patch "/dashboard/terminals/#{@acme_terminal.id}", params: { terminal: { payment_connection_id: connect_test_mode(@other).id } }

    assert_response :unprocessable_entity
    assert_equal @acme, @acme_terminal.reload.payment_connection.account
  end

  test "the donations list shows only this account" do
    @other.donations.create!(amount: 5, terminal: @other_terminal, donor_name: "Someone Else")
    sign_in_to @acme

    get "/dashboard/donations"

    assert_response :success
    assert_no_match "Someone Else", response.body
  end

  test "brand images are per account" do
    logo = BrandImage.create!(account: @acme, kind: "logo", data: "\x89PNG\r\n\x1A\n1".b, content_type: "image/png", digest: "abc")
    host! @other.host
    get "/brand/logo"
    assert_response :not_found

    host! @acme_terminal.hostname
    get "/brand/logo", params: { v: logo.digest }
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "the super admin isn't reachable from account hosts" do
    host! @acme.host
    get "/admin/dashboard"

    assert_response :not_found
  end

  test "an expired or foreign handover token doesn't sign in" do
    token = @other.users.first.generate_token_for(:handover)
    host! @acme.host

    get "/session/#{token}"
    assert_redirected_to "/login"
    get "/dashboard"
    assert_redirected_to "/login"
  end
end
