require "test_helper"

class MarketingTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "landing page in every language, without the SumUp guide" do
    get "/"
    assert_redirected_to "/de"

    %w[de en bs].each do |locale|
      get "/#{locale}"
      assert_response :success
      assert_select "#how .step", 4
      assert_select "#sumup", 0
      assert_select ".site-nav a[href$='#sumup']", 0
    end
  end

  test "pricing shows the yearly plan, extra terminals and the guarantee" do
    { "de" => ["35 €", "+5 €"], "en" => ["€35", "+€5"], "bs" => ["35 €", "+5 €"] }.each do |locale, (price, addon)|
      get "/#{locale}"
      assert_select ".plan__price", price
      assert_select ".plan__addon", /#{Regexp.escape(addon)}/
      assert_select ".plan__guarantee p"
    end
  end

  test "legal pages and login lookup render" do
    %w[impressum privacy terms login signup].each do |page|
      get "/de/#{page}"
      assert_response :success, page
    end
  end

  test "signup creates an account with a working test terminal and hands over to its host" do
    assert_difference -> { Account.count } => 1, -> { Terminal.count } => 1 do
      post "/de/signup", params: { signup: { organisation_name: "Džemat Nürnberg", subdomain: "dzemat-nurnberg", name: "Adem",
                                             email: "a@example.com", password: "correct-horse-battery", terms: "1" } }
    end
    assert_match %r{\Ahttp://dzemat-nurnberg\.localhost/session/.+welcome=1\z}, response.location

    terminal = Account.find_by(subdomain: "dzemat-nurnberg").terminals.first
    assert terminal.test_mode?
    assert_equal "terminal1.dzemat-nurnberg.localhost", terminal.hostname

    get response.location
    assert_redirected_to %r{/dashboard}
    follow_redirect!
    assert_response :success
  end

  test "signup shows errors and needs the terms" do
    assert_no_difference -> { Account.count } do
      post "/de/signup", params: { signup: { organisation_name: "X", subdomain: "admin", name: "A", email: "bad", password: "short", terms: "0" } }
    end
    assert_response :unprocessable_entity
    assert_select ".signup-form__errors li", minimum: 3
  end

  test "subdomain check" do
    create_account

    get "/de/signup/check", params: { subdomain: "acme" }
    assert_not response.parsed_body["available"]
    get "/de/signup/check", params: { subdomain: "free-name" }
    assert response.parsed_body["available"]
  end
end
