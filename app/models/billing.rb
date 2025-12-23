class Billing < ApplicationRecord
  belongs_to :subscriber
  has_many :payments, dependent: :destroy

  validates :start_date, :end_date, :due_date, :amount, :status, presence: true

  validates :subscriber_id, uniqueness: {
    scope: [ :start_date, :end_date ],
    message: "already has a billing for that period"
  }
end
