class AdminUser < ApplicationRecord
  has_secure_password

  ROLES = %w[
    admin
    billing
    accounting
  ].freeze

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role,  inclusion: { in: ROLES }
end
