# app/controllers/api/v1/payments_controller.rb
class Api::V1::PaymentsController < ApplicationController
  before_action :authenticate_request!

  # GET /api/v1/payments
  #
  # Query params (all optional):
  #   ?year=2025
  #     -or-
  #   ?start_year=2024&end_year=2025
  #
  #   ?status=Confirmed|Processing|Failed
  #   ?method=GCash|Cash|Bank%20Transfer
  #
  #   ?page=1&per_page=20   (per_page capped at 100)
  #
  # Notes:
  # - Filters are by payment_date (the payment's actual date).
  # - Only payments for the current_subscriber are returned.
  def index
    payments = Payment
      .joins(billing: :subscriber)
      .where(billings: { subscriber_id: current_subscriber.id })
      .includes(:billing) # N+1 safe for serializer
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
    payments = payments.where(method: params[:method]) if params[:method].present?

    # ---- Pagination ----
    page     = (params[:page] || 1).to_i
    per_page = [(params[:per_page] || 20).to_i, 100].min
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

  private

  # Shape expected by your frontend Payments tab
  def serialize_payment(p)
    {
      id: p.id,
      payment_date: p.payment_date,         # e.g., "2025-06-15"
      amount: p.amount.to_f,                # numeric
      method: p.method,                     # "GCash" | "Cash" | "Bank Transfer"
      status: p.status,                     # "Confirmed" | "Processing" | "Failed"
      attachment: p.attachment,
      reference_number: p.reference_number,
      billing_id: p.billing_id,

      # Useful context for display if needed:
      billing_period_start: p.billing&.start_date,
      billing_period_end: p.billing&.end_date,
      billing_status: p.billing&.status     # "Open" | "Closed" | "Overdue"
    }
  end
end
