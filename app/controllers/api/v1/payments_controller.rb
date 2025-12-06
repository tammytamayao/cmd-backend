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

  # GET /api/v1/payments/:id/receipt_url
  # Generate a signed URL for downloading the payment receipt
  def receipt_url
    payment = Payment.joins(billing: :subscriber)
                     .where(billings: { subscriber_id: current_subscriber.id })
                     .find_by(id: params[:id])

    return render json: { error: "Payment not found" }, status: :not_found unless payment

    if payment.attachment.nil?
      return render json: { error: "Receipt not found for this payment" }, status: :not_found
    end

    url_result = S3Helper.generate_signed_url(payment.attachment)

    if url_result[:success]
      render json: { data: url_result }, status: :ok
    else
      render json: { error: url_result[:error] }, status: :internal_server_error
    end
  end

  def show
    payment = Payment
      .joins(billing: :subscriber)
      .includes(:billing)
      .where(billings: { subscriber_id: current_subscriber.id })
      .find_by(id: params[:id])

    return render json: { error: "Payment not found" }, status: :not_found unless payment

    receipt_url = nil
    if payment.attachment.present?
      signed = S3Helper.generate_signed_url(payment.attachment)
      receipt_url = signed[:url] if signed[:success]
    end

    render json: {
      data: serialize_payment(payment).merge(
        receipt_url: receipt_url
      )
    }, status: :ok
  end


  # POST /api/v1/payments
  # Expects FormData with:
  # - billing_id (required)
  # - payment_method: "GCASH" | "BANK_TRANSFER" | "CASH" (required)
  # - receipt (required; file upload for payment receipt)
  # - gcash_reference / reference_number (optional)
  def create
    billing = current_subscriber.billings.find_by(id: params[:billing_id])
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
