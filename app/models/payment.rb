# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :billing

  validates :billing_id, presence: true
  validates :payment_date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true, inclusion: { in: %w[GCash Cash "Bank Transfer"], message: "%{value} is not a valid payment method" }
  validates :status, presence: true, inclusion: { in: %w[Processing Completed Failed], message: "%{value} is not a valid status" }
  validates :attachment, presence: true

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_payment_method, ->(method) { where(payment_method: method) }
end
