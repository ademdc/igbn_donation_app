require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: "correct-horse-battery", admin: true)
    @account = create_account
    create_terminal(@account)
  end

  def log_in
    post "/admin/login", params: { email: @admin.email, password: "correct-horse-battery" }
  end

  test "pages need an admin" do
    get "/admin/accounts"
    assert_redirected_to "/admin/login"

    post "/admin/login", params: { email: @account.users.first.email, password: "correct-horse-battery" }
    assert_response :unprocessable_entity
  end

  test "lists and searches accounts" do
    log_in
    sumup_connection(@account)
    get "/admin/dashboard"
    assert_response :success
    get "/admin/accounts", params: { q: "acm" }
    assert_select "td a", "Acme"
    get "/admin/accounts", params: { q: "zzz" }
    assert_select "td a", 0
    get "/admin/accounts/#{@account.id}"
    assert_response :success
    assert_no_match "sup_sk_secret1234", response.body
  end

  test "suspends an account" do
    log_in

    patch "/admin/accounts/#{@account.id}", params: { account: { status: "suspended" } }

    assert @account.reload.suspended?
  end

  test "opens an account's dashboard as its owner" do
    log_in

    post "/admin/accounts/#{@account.id}/impersonate"

    assert_match %r{\Ahttp://acme\.localhost/session/}, response.location
    get response.location
    assert_redirected_to "/dashboard"
    follow_redirect!
    assert_response :success
  end
end

class AdminLocaleTest < ActionDispatch::IntegrationTest
  test "the admin is in English regardless of the default locale" do
    host! "localhost"
    admin = User.create!(name: "Admin", email: "admin@example.com", password: "correct-horse-battery", admin: true)
    account = create_account
    post "/admin/login", params: { email: admin.email, password: "correct-horse-battery" }

    get "/admin/accounts/#{account.id}"

    assert_match "0 donations", response.body
  end
end
