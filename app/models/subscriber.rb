# app/models/subscriber.rb
class Subscriber < ApplicationRecord
  has_secure_password
   has_many :billings, dependent: :destroy

  # Keep these in this order so phone is normalized before password generation
  before_validation :normalize_phone
  before_validation :set_default_password, on: :create

  attribute :requires_password_change, :boolean, default: true

  validates :phone_number, presence: true, uniqueness: true,
                           format: { with: /\A\+\d{10,15}\z/ } # enforce +E.164
  validates :password, length: { minimum: 6 }, if: -> { password.present? }

  # Reuse the same normalization in controllers/services
  def self.normalize_raw_phone(raw)
    s = raw.to_s
    # If already begins with '+' and digits, keep it
    return s if s.start_with?('+') && s[1..].match?(/\A\d+\z/)

    digits = s.gsub(/\D/, "")
    case
    when digits.start_with?("63") && digits.length == 12
      "+#{digits}"                        # 63XXXXXXXXXX -> +63XXXXXXXXXX
    when digits.length == 11 && digits.start_with?("0")
      "+63#{digits[1..]}"                 # 09XXXXXXXXX  -> +639XXXXXXXXX
    when digits.length == 10
      "+63#{digits}"                      # 9XXXXXXXXX   -> +639XXXXXXXXX
    else
      "+#{digits}"                        # fallback
    end
  end

  private

  def normalize_phone
    return if phone_number.blank?
    self.phone_number = self.class.normalize_raw_phone(phone_number)
  end

  # initial password: lastname (lowercase, no spaces) + last 4 digits of normalized phone
  def set_default_password
    return if password_digest.present? || password.present?
    normalized = phone_number.to_s # already normalized by earlier callback
    last4 = normalized.gsub(/\D/, "")[-4, 4]
    lname = last_name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    self.password = "#{lname}#{last4}" if lname.present? && last4.present?
  end
end
