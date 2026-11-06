require "test_helper"

class DonationMailerTest < ActionMailer::TestCase
  test "comes from the account, in the donor's language" do
    account = create_account
    account.update!(receipt_footer: "Musterstr. 1\n90441 Nürnberg", terminal_copy: { "bs" => { "thank_you" => "Hvala!" } })
    donation = account.donations.create!(amount: 12.5, terminal: create_terminal(account), donor_email: "d@example.com", locale: "bs")

    mail = DonationMailer.confirmation_email(donation)

    assert_equal ["d@example.com"], mail.to
    assert_equal "Hvala na vašoj donaciji za Acme", mail.subject
    assert_equal "Acme", mail[:from].display_names.first
    assert_equal ["owner@acme.test"], mail.reply_to
    assert_match "€12,50", mail.html_part.body.to_s
    assert_match "Hvala!", mail.html_part.body.to_s
    assert_match "90441", mail.text_part.body.to_s
  end
end
