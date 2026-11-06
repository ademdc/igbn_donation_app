namespace :admin do
  desc "Create or update a super-admin user (prompts for the password)"
  task create: :environment do
    require "io/console"

    email = ENV["EMAIL"].presence || abort("Usage: bin/rails admin:create EMAIL=you@example.com [NAME='Your Name']")
    print "Password for #{email} (min. 10 characters): "
    # Hide the input when there is a terminal (fly ssh console -C has none without --pty)
    password = ($stdin.tty? ? $stdin.noecho(&:gets) : $stdin.gets).to_s.chomp
    puts

    user = User.find_or_initialize_by(email: email.downcase, admin: true, account_id: nil)
    user.name = ENV["NAME"].presence || user.name || email
    user.password = password

    if user.save
      puts "Admin #{user.email} saved."
    else
      abort user.errors.full_messages.to_sentence
    end
  end
end
