# app/controllers/api/v1/payments_controller.rb
class Api::V1::PaymentsController < ApplicationController
  before_action :authenticate_request!

  # GET /api/v1/payments
  def index
    payments = Payment
      .joins(billing: :subscriber)
      .where(billings: { subscriber_id: current_subscriber.id })
      .includes(:billing)
      .order(Arel.sql("payment_date DESC NULLS LAST"), id: :desc)

    # ---- Date window by payment_date ----
    if params[:year].present?
      y = params[:year].to_i
      payments = payments.where(payment_date: Date.new(y, 1, 1)..Date.new(y, 12, 31))
    else
      start_year = (params[:start_year] || 2024).to_i
      end_year   = (params[:end_year]   || 2025).to_i
      payments = payments.where(payment_date: Date.new(start_year, 1, 1)..Date.new(end_year, 12, 31))
    end

    # ---- Optional filters ----
    payments = payments.where(status: params[:status]) if params[:status].present?
    if params[:payment_method].present?
      payments = payments.where("LOWER(payment_method) = ?", params[:payment_method].downcase)
    end

    # ---- Pagination ----
    page     = (params[:page] || 1).to_i
    per_page = [ (params[:per_page] || 20).to_i, 100 ].min
    total    = payments.count
    payments = payments.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: payments.map { |p| serialize_payment(p) },
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total / per_page.to_f).ceil
      }
    }
  end

  # POST /api/v1/payments
  # Expects FormData with:
  # - billing_id (required)
  # - payment_method: "GCASH" | "BANK_TRANSFER" | "CASH" (required)
  # - gcash_reference / reference_number (optional)
  # - receipt (ignored for now; attachment URL is hardcoded)
  def create
    billing = current_subscriber.billings.find_by(id: params[:billing_id])
    return render json: { error: "Billing not found" }, status: :not_found unless billing

    kind = params[:payment_method].to_s.upcase
    method_label = case kind
    when "GCASH"         then "GCash"
    when "BANK_TRANSFER" then "Bank Transfer"
    when "CASH"          then "Cash"
    else "Cash"
    end

    payment = Payment.new(
      billing_id:       billing.id,
      payment_date:     Time.zone.today,
      amount:           billing.amount,   # trust server
      status:           "Processing",
      payment_method:   method_label,
      reference_number: params[:gcash_reference].presence || params[:reference_number],
      attachment:       "https://example.com/static-receipts/placeholder.jpg" # hardcoded for now
    )

    if payment.save
      render json: { data: serialize_payment(payment) }, status: :created
    else
      render json: { error: payment.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  # Shape returned to the frontend
  def serialize_payment(p)
    {
      id: p.id,
      payment_date: p.payment_date,
      amount: p.amount.to_f,
      payment_method: p.payment_method,   # FE expects payment_method now
      status: p.status,
      attachment: p.attachment,           # URL string (hardcoded)
      reference_number: p.reference_number,
      billing_id: p.billing_id,
      billing_period_start: p.billing&.start_date,
      billing_period_end:   p.billing&.end_date,
      billing_status:       p.billing&.status
    }
  end
end
