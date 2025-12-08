# app/controllers/api/admin/billings_controller.rb
class Api::Admin::BillingsController < ApplicationController
  before_action :authenticate_admin!

  PER_PAGE = 10

  # GET /api/admin/billings
  # Optional: ?subscriber_id=123 to filter
  def index
    Rails.logger.info("[ADMIN] #{current_admin.email} listing billings")

    billings = Billing
      .includes(:subscriber)
      .order(created_at: :desc)

    if params[:subscriber_id].present?
      billings = billings.where(subscriber_id: params[:subscriber_id])
    end

    page     = (params[:page] || 1).to_i
    per_page = (params[:per_page] || PER_PAGE).to_i
    total    = billings.count

    billings = billings.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: billings.map { |b| serialize_billing(b) },
      meta: {
        page:        page,
        per_page:    per_page,
        total:       total,
        total_pages: (total / per_page.to_f).ceil
      }
    }
  end

  # GET /api/admin/billings/:id
  def show
    Rails.logger.info("[ADMIN] #{current_admin.email} fetching billing #{params[:id]}")

    billing = Billing.includes(:subscriber).find_by(id: params[:id])
    return render json: { error: "Billing not found" }, status: :not_found unless billing

    render json: { data: serialize_billing(billing) }, status: :ok
  end

  # PATCH /api/admin/billings/:id
  def update
    Rails.logger.info("[ADMIN] #{current_admin.email} updating billing #{params[:id]}")

    billing = Billing.find_by(id: params[:id])
    return render json: { error: "Billing not found" }, status: :not_found unless billing

    if billing.update(billing_params)
      render json: { data: serialize_billing(billing) }, status: :ok
    else
      render json: {
        error: "Validation failed",
        details: billing.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def serialize_billing(billing)
    subscriber = billing.subscriber

    {
      id:         billing.id,
      start_date: billing.start_date,
      end_date:   billing.end_date,
      amount:     billing.amount.to_f,
      due_date:   billing.due_date,
      status:     billing.status,
      created_at: billing.created_at.as_json,
      updated_at: billing.updated_at.as_json,

      subscriber_id: billing.subscriber_id,
      subscriber: {
        id:            subscriber&.id,
        serial_number: subscriber&.serial_number,
        first_name:    subscriber&.first_name,
        last_name:     subscriber&.last_name,
        phone_number:  subscriber&.phone_number,
        package:       subscriber&.package,
        plan:          subscriber&.plan,
        zone:          subscriber&.zone
      }
    }
  end

  # Adjust permitted fields as needed
  def billing_params
    params.permit(
      :status,
      :start_date,
      :end_date,
      :due_date,
      :amount
    )
  end
end
