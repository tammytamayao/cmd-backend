# app/controllers/api/admin/payments_controller.rb
class Api::Admin::PaymentsController < ApplicationController
  # TODO: Add authentication for admin endpoints in production.
  # Currently unauthenticated for debugging purposes only.
  # When implementing authentication, add: before_action :authenticate_request!

  # GET /api/admin/payments
  # TODO: Implement authentication for admin endpoints in production.
  # This endpoint is currently unauthenticated and should require admin privileges.
  def index
    Rails.logger.warn("[ADMIN] Unauthenticated access to list payments")

    payments = Payment
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

  # GET /api/admin/payments/:id
  # TODO: Implement authentication for admin endpoints in production.
  # This endpoint is currently unauthenticated and should require admin privileges.
  def show
    Rails.logger.warn("[ADMIN] Unauthenticated access to get payment #{params[:id]}")

    payment = Payment.find_by(id: params[:id])
    return render json: { error: "Payment not found" }, status: :not_found unless payment

    render json: { data: serialize_payment(payment) }, status: :ok
  end

  # POST /api/admin/payments
  # TODO: Implement authentication for admin endpoints in production.
  # This endpoint is currently unauthenticated and should require admin privileges.
  # Expects FormData with:
  # - billing_id (required)
  # - payment_method: "GCASH" | "BANK_TRANSFER" | "CASH" (required)
  # - receipt (required; file upload for payment receipt)
  # - gcash_reference / reference_number (optional)
  def create
    Rails.logger.warn("[ADMIN] Unauthenticated access to create payment - billing_id: #{params[:billing_id]}")

    billing = Billing.find_by(id: params[:billing_id])
    return render json: { error: "Billing not found" }, status: :not_found unless billing

    # Validate receipt file is provided
    receipt_file = params[:receipt]
    if receipt_file.nil?
      return render json: { error: "Receipt file is required" }, status: :bad_request
    end

    kind = params[:payment_method].to_s.upcase
    method_label = case kind
    when "GCASH"         then "GCash"
    when "BANK_TRANSFER" then "Bank Transfer"
    when "CASH"          then "Cash"
    else "Cash"
    end

    # Upload receipt to S3
    upload_result = S3Helper.upload_receipt(receipt_file, billing.id)

    unless upload_result[:success]
      return render json: { error: upload_result[:error] }, status: :bad_request
    end

    payment = Payment.new(
      billing_id:          billing.id,
      payment_date:        Time.zone.today,
      amount:              billing.amount,
      status:              "Processing",
      payment_method:      method_label,
      reference_number:    params[:gcash_reference].presence || params[:reference_number],
      attachment:          upload_result[:s3_key],
      receipt_filename:    upload_result[:filename],
      receipt_size:        upload_result[:size],
      receipt_mime_type:   upload_result[:mime_type],
      receipt_uploaded_at: upload_result[:uploaded_at]
    )

    if payment.save
      render json: { data: serialize_payment(payment) }, status: :created
    else
      # Rollback S3 upload if database save fails
      S3Helper.delete(upload_result[:s3_key])
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
      payment_method: p.payment_method,
      status: p.status,
      attachment: p.attachment,               # S3 key
      reference_number: p.reference_number,
      billing_id: p.billing_id,
      billing_period_start: p.billing&.start_date,
      billing_period_end: p.billing&.end_date,
      billing_status: p.billing&.status,
      receipt: {
        filename: p.receipt_filename,
        size: p.receipt_size,
        mime_type: p.receipt_mime_type,
        uploaded_at: p.receipt_uploaded_at
      }
    }
  end
end
