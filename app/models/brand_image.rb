# An account's logo or background. Kept in the database so uploads survive deploys:
# Fly machines have no persistent disk, and these are small and read rarely.
class BrandImage < ApplicationRecord
  KINDS = %w[logo background].freeze
  MAX_BYTES = 2.megabytes
  # Recognised from the file's bytes, not what the browser claims. No SVG: it can carry scripts.
  SIGNATURES = {
    "image/png" => "\x89PNG\r\n\x1A\n".b,
    "image/jpeg" => "\xFF\xD8\xFF".b,
    "image/webp" => nil
  }.freeze

  belongs_to :account

  validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :account_id }
  validates :data, :content_type, presence: true
  validate :small_enough

  def self.store(account, kind, upload)
    bytes = upload.read
    image = account.brand_images.find_or_initialize_by(kind: kind)
    image.assign_attributes(data: bytes, content_type: detect_type(bytes), digest: Digest::SHA256.hexdigest(bytes).first(16))
    image.save
    image
  end

  def self.detect_type(bytes)
    return "image/webp" if bytes.byteslice(0, 4) == "RIFF".b && bytes.byteslice(8, 4) == "WEBP".b
    SIGNATURES.find { |_, signature| signature && bytes.start_with?(signature) }&.first
  end

  private

  def small_enough
    errors.add(:data, :too_long, count: MAX_BYTES) if data.to_s.bytesize > MAX_BYTES
  end
end
