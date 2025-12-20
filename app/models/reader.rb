class Reader < ApplicationRecord
  validates :subdomain, presence: true, uniqueness: true
  validates :sumup_reader_id, presence: true

  def self.find_by_subdomain!(subdomain)
    find_by!(subdomain: subdomain)
  end
end
