class Api::Admin::SubscribersController < ApplicationController
  before_action :authenticate_admin!

  # GET /api/admin/subscribers
  def index
    Rails.logger.info("[ADMIN] #{current_admin.email} listing subscribers dashboard")

    period_start = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
    period_end   = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current.end_of_month

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
      .order(:last_name, :first_name)

    page     = (params[:page] || 1).to_i
    per_page = [(params[:per_page] || 10).to_i, 100].min
    total    = subscribers.count
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

  private

  def serialize_subscriber(s)
    {
      id: s.id,
      serial_number: s.serial_number,
      first_name: s.first_name,
      last_name: s.last_name,
      phone_number: s.phone_number,
      zone: s.zone,
      plan: s.plan,
      brate: s.brate,
      package: s.package,
      package_speed: s.package_speed,
      date_installed: s.date_installed
    }
  end
end
