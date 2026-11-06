require "test_helper"
require "rake"

class AdminTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:create")
    Rake::Task["admin:create"].reenable
    ENV["EMAIL"] = "Admin@Example.com"
    ENV["NAME"] = "Admin"
  end

  teardown do
    ENV.delete("EMAIL")
    ENV.delete("NAME")
    $stdin = STDIN
  end

  test "creates a super admin who can log in" do
    $stdin = StringIO.new("correct-horse-battery\n")

    capture_io { Rake::Task["admin:create"].invoke }

    user = User.admins.find_by!(email: "admin@example.com")
    assert_nil user.account_id
    assert user.authenticate("correct-horse-battery")
  end
end
