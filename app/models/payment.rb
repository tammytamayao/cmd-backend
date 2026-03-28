class Payment < ApplicationRecord
  belongs_to :billing

  validates :billing_id, presence: true
  validates :payment_date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method,
            presence: true,
            inclusion: {
              in: [ "GCash", "Cash", "Bank Transfer" ],
              message: "%{value} is not a valid payment method"
            }
  validates :status,
            presence: true,
            inclusion: {
              in: [ "Processing", "Completed", "Failed" ],
              message: "%{value} is not a valid status"
            }
  validates :attachment, presence: true

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_payment_method, ->(method) { where(payment_method: method) }

  after_save :sync_billing_status!
  after_destroy :sync_billing_status_after_destroy!

  private

  def sync_billing_status!
    return unless billing.present?

    has_completed_payment = billing.payments.where(status: "Completed").exists?
    billing.update!(status: has_completed_payment ? "paid" : "unpaid")
  end

  def sync_billing_status_after_destroy!
    return unless billing.present?

    has_completed_payment = billing.payments.where(status: "Completed").exists?
    billing.update!(status: has_completed_payment ? "paid" : "unpaid")
  end
end
