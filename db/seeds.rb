# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

# Seed readers - uses ENV variables for SumUp reader IDs
Reader.find_or_create_by!(subdomain: 'donation-terminal1') do |reader|
  reader.sumup_reader_id = ENV['SUMUP_READER1_ID']
  reader.name = 'Donation Terminal 1'
end

Reader.find_or_create_by!(subdomain: 'donation-terminal2') do |reader|
  reader.sumup_reader_id = ENV['SUMUP_READER2_ID']
  reader.name = 'Donation Terminal 2'
end
