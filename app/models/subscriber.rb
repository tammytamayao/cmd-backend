class Subscriber < ApplicationRecord
  has_secure_password

  before_validation :normalize_phone
  before_validation :set_default_password, on: :create

  # default: subscriber must change the generated password at first login
  attribute :requires_password_change, :boolean, default: true

  validates :phone_number, presence: true, uniqueness: true,
                           format: { with: /\A\+?\d{8,15}\z/ }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }

  private

  def normalize_phone
    return if phone_number.blank?
    digits = phone_number.gsub(/\D/, "")
    self.phone_number = digits.start_with?("+") ? digits : "+#{digits}"
  end

  # initial password: lastname (lowercase, no spaces) + last 4 digits of phone
  def set_default_password
    return if password_digest.present? || password.present?
    last4 = phone_number.to_s.gsub(/\D/, "")[-4, 4]
    lname = last_name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    if lname.present? && last4.present?
      self.password = "#{lname}#{last4}" # e.g., TAMAYAO + 5446 => "tamayao5446"
    end
  end
end
