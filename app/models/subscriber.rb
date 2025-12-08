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

  # Optional helper for login – now just trims spaces.
  def self.normalize_raw_phone(raw)
    raw.to_s.gsub(/\s+/, "")
  end

  private

  # initial password: lastname (lowercase, no spaces) + last 4 digits of phone
  def set_default_password
    return if password_digest.present? || password.present?

    digits = phone_number.to_s.gsub(/\D/, "")
    last4  = digits[-4, 4]
    lname  = last_name.to_s.downcase.gsub(/[^a-z0-9]/, "")

    self.password = "#{lname}#{last4}" if lname.present? && last4.present?
  end
end
