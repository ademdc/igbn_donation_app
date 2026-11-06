# Demo data for development: http://demo.localhost:3030 (owner@demo.test / demo-password-1)
# and the super admin at http://localhost:3030/admin (admin@demo.test, same password).
abort "Seeds are for development" unless Rails.env.development?

User.find_or_create_by!(email: "admin@demo.test", admin: true) do |user|
  user.name = "Admin"
  user.password = "demo-password-1"
end

Account.find_by(subdomain: "demo")&.destroy!

account = Account.create!(
  name: "Džemat Demo", subdomain: "demo", show_recent_donations: true, preset_amounts: [5, 10, 20, 50],
  terminal_copy: {
    "de" => { "title" => "Spenden Sie für unsere Moschee", "subtitle" => "Jede Spende hilft unserer Gemeinde." },
    "bs" => { "title" => "Donirajte za našu džamiju", "subtitle" => "Svaka donacija pomaže našem džematu." }
  },
  receipt_footer: "Džemat Demo\nMusterstraße 1, 90441 Nürnberg"
)
account.users.create!(name: "Amina", email: "owner@demo.test", password: "demo-password-1", locale: "de")

# Only for the statistics: a real SumUp key is needed to take payments on these
sumup = account.payment_connections.create!(
  provider: "sumup", credentials: { "api_key" => "demo", "merchant_code" => "MK01A8C2" }, verified_at: Time.current
)
test_mode = account.payment_connections.create!(provider: "test")
entrance = account.terminals.create!(name: "Haupteingang", slug: "eingang", payment_connection: sumup, provider_reader_id: "rdr_demo1")
cafe = account.terminals.create!(name: "Café", slug: "cafe", payment_connection: sumup, provider_reader_id: "rdr_demo2")
account.terminals.create!(name: "Terminal 1", slug: "terminal1", payment_connection: test_mode)

names = ["Emina H.", "Tarik S.", nil, "Lejla M.", nil, "Haris K.", nil]
random = Random.new(42)
(0..89).each do |days_ago|
  date = days_ago.days.ago
  # Friday prayers bring in most of the week's donations
  count = date.friday? ? random.rand(12..22) : random.rand(0..4)
  count.times do
    account.donations.create!(
      amount: [5, 5, 10, 10, 20, 50, 7.5, 100].sample(random: random), terminal: [entrance, entrance, cafe].sample(random: random),
      status: "successful", donor_name: names.sample(random: random), created_at: date.change(hour: random.rand(10..20))
    )
  end
end
