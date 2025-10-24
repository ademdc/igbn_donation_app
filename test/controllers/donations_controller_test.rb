require "test_helper"

class DonationsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get donations_create_url
    assert_response :success
  end

  test "should get status" do
    get donations_status_url
    assert_response :success
  end
end
