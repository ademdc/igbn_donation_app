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
      assert_select ".plan__guarantee p", /120/
    end
  end

  test "the imprint names the company, in every language, with no placeholders left" do
    { "de" => "Geschäftsführung", "en" => "Director", "bs" => "Direktor" }.each do |locale, label|
      get "/#{locale}/impressum"

      assert_select ".legal", /Everline društvo sa ograničenom odgovornošću/
      assert_select ".legal", /Samra Hodzic/
      assert_select ".legal", /4203057970009/
      assert_select ".legal", /65-01-0536-22/
      assert_select ".legal", /423057970009/
      assert_select ".legal h2", label
      assert_no_match(/\[[A-Z][a-z]+/, css_select(".legal").text)
    end
  end

  test "signing up confirms the authority to act for the community" do
    { "de" => "berechtigt", "en" => "authorised", "bs" => "ovlašten" }.each do |locale, word|
      get "/#{locale}/signup"
      assert_select ".signup-terms", /#{word}/
    end
  end

  test "the privacy policy names Postmark and covers transfers outside the EU" do
    get "/de/privacy"

    assert_select ".legal", /Postmark/
    assert_select ".legal", /Standard Contractual Clauses/
    assert_select ".legal", /Bosnia and Herzegovina/
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
