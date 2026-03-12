# frozen_string_literal: true

class Payment < ApplicationRecord
  VALID_METHODS = %w[GCash Cash Bank\ Transfer Maya Card GrabPay].freeze
  VALID_STATUSES = %w[Processing Completed Failed].freeze

  belongs_to :billing

  validates :billing_id, presence: true
  validates :payment_date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true, inclusion: { in: VALID_METHODS, message: "%{value} is not a valid payment method" }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES, message: "%{value} is not a valid status" }
  validates :attachment, presence: true

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_payment_method, ->(method) { where(payment_method: method) }
  scope :by_gateway, ->(provider) { where(gateway_provider: provider) }

  # Whether this payment was processed through a payment gateway (vs manual receipt upload).
  def gateway_payment?
    gateway_provider.present?
  end
end
