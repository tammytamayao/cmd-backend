# app/models/subscriber.rb
class Subscriber < ApplicationRecord
  has_secure_password
  has_many :billings, dependent: :destroy
  has_many :file_uploads, dependent: :destroy

  # ✅ Only set default password; do NOT normalize phone
  before_validation :set_default_password, on: :create

  attribute :requires_password_change, :boolean, default: true

  # ✅ Allow ONLY PH-style 11-digit numbers starting with 0
  # (example: 09957795446). Remove +63 entirely if you don't want it.
  validates :phone_number, presence: true, uniqueness: true,
                           format: {
                             with: /\A0\d{10}\z/,
                             message: "must be 11 digits starting with 0"
                           }

  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :serial_number, presence: true, uniqueness: true

  # Optional helper for login – now just trims spaces.
  def self.normalize_raw_phone(raw)
    raw.to_s.gsub(/\s+/, "")
  end

  private

  def set_default_password
    return if password_digest.present? || password.present?

    lname = last_name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    serial_prefix = serial_number.to_s[0, 4] # includes dash if present

    if lname.present? && serial_prefix.present?
      self.password = "#{lname}#{serial_prefix}"
    end
  end
end
