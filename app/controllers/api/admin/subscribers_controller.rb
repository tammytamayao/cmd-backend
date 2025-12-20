class Api::Admin::SubscribersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_subscriber, only: [ :update, :show ]

  # GET /api/admin/subscribers
  def index
    Rails.logger.info("[ADMIN] #{current_admin.email} listing subscribers dashboard")

    begin
      period_start =
        params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
      period_end =
        params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current.end_of_month
    rescue ArgumentError
      return render json: { error: "Invalid start_date or end_date" }, status: :bad_request
    end

    total_revenue = Payment
      .where(status: "Completed", payment_date: period_start..period_end)
      .sum(:amount)
      .to_f

    total_overdue = Billing
      .where(status: "Overdue")
      .sum(:amount)
      .to_f

    new_subscribers = Subscriber
      .where(date_installed: period_start..period_end)
      .count

    subscribers = Subscriber
      .includes(:billings)
      .order(:last_name, :first_name, :id)

    # ---- Search (q) across subscribers (SQLite-safe) ----
    if params[:q].present?
      q = params[:q].to_s.strip.downcase
      escaped = ActiveRecord::Base.sanitize_sql_like(q)
      like = "%#{escaped}%"

      subscribers = subscribers.where(
        <<~SQL,
          LOWER(CAST(subscribers.id AS TEXT)) LIKE :like
          OR LOWER(COALESCE(subscribers.serial_number, '')) LIKE :like
          OR LOWER(COALESCE(subscribers.first_name, '')) LIKE :like
          OR LOWER(COALESCE(subscribers.last_name, '')) LIKE :like
          OR LOWER(COALESCE(subscribers.phone_number, '')) LIKE :like
          OR LOWER(COALESCE(subscribers.zone, '')) LIKE :like
        SQL
        like: like
      )
    end

    # ---- Pagination ----
    page     = (params[:page].presence || 1).to_i
    per_page = [(params[:per_page].presence || 10).to_i, 100].min
    per_page = 10 if per_page <= 0

    total = subscribers.count
    subscribers = subscribers.offset((page - 1) * per_page).limit(per_page)

    render json: {
      stats: {
        period_start: period_start,
        period_end: period_end,
        total_revenue: total_revenue,
        total_overdue: total_overdue,
        new_subscribers: new_subscribers
      },
      data: subscribers.map { |s| serialize_subscriber(s) },
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total / per_page.to_f).ceil
      }
    }
  end

  def show
    render json: { data: serialize_subscriber(@subscriber) }, status: :ok
  end

  # POST /api/admin/subscribers
  def create
    Rails.logger.info("[ADMIN] #{current_admin.email} creating subscriber")

    subscriber = Subscriber.new(subscriber_params)

    if subscriber.save
      render json: { data: serialize_subscriber(subscriber) }, status: :created
    else
      render json: { error: subscriber.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :bad_request
  end

  # PATCH /api/admin/subscribers/:id
  def update
    Rails.logger.info("[ADMIN] #{current_admin.email} updating subscriber ##{@subscriber.id}")

    if @subscriber.update(subscriber_params)
      render json: { data: serialize_subscriber(@subscriber) }, status: :ok
    else
      render json: { error: @subscriber.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def set_subscriber
    @subscriber = Subscriber.find(params[:id])
  end

  # IMPORTANT: include all fields you want editable
  def subscriber_params
    params.require(:subscriber).permit(
      :collector,
      :zone,
      :date_installed,
      :last_name,
      :first_name,
      :phone_number,
      :alternative_phone,
      :serial_number,
      :tvconnect,
      :package,
      :plan,
      :brate,
      :mc_address,
      :stb,
      :cas,
      :package_speed,
      :requires_password_change
    )
  end

  # IMPORTANT: return the fields needed by the edit modal
  def serialize_subscriber(s)
    {
      id: s.id,
      collector: s.collector,
      zone: s.zone,
      date_installed: s.date_installed,
      last_name: s.last_name,
      first_name: s.first_name,
      phone_number: s.phone_number,
      alternative_phone: s.alternative_phone,
      serial_number: s.serial_number,
      tvconnect: s.tvconnect,
      package: s.package,
      plan: s.plan,
      brate: s.brate,
      mc_address: s.mc_address,
      stb: s.stb,
      cas: s.cas,
      package_speed: s.package_speed,
      requires_password_change: s.requires_password_change
    }
  end
end
