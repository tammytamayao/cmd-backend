# app/controllers/api/v1/billings_controller.rb
class Api::V1::BillingsController < ApplicationController
  before_action :authenticate_request!

  # GET /api/v1/billings
  #
  # Optional query params:
  #   ?year=2025
  #   ?start_year=2024&end_year=2025
  #   ?status=paid,unpaid,overdue
  #       - overdue = unpaid AND due_date < today (derived here)
  #   ?page=1&per_page=12
  def index
    billings = current_subscriber
                 .billings
                 .includes(:payments)
                 .order(start_date: :desc)

    # Only apply year / range filters IF provided.
    billings = apply_year_filter(billings)

    # Optional status filter (paid / unpaid / overdue)
    billings = apply_status_filter(billings)

    # --- Simple pagination ---
    page     = (params[:page] || 1).to_i
    per_page = [ (params[:per_page] || 12).to_i, 100 ].min
    total    = billings.count
    billings = billings.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: billings.map { |b| serialize_billing(b) },
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total / per_page.to_f).ceil
      }
    }
  end

  private

  # Apply year filter only when params are explicitly given.
  # If no year/start_year/end_year is present, we return the scope unchanged.
  def apply_year_filter(scope)
    if params[:year].present?
      y = params[:year].to_i
      scope.where(start_date: Date.new(y, 1, 1)..Date.new(y, 12, 31))

    elsif params[:start_year].present? || params[:end_year].present?
      start_year = (params[:start_year] || params[:end_year]).to_i
      end_year   = (params[:end_year]   || params[:start_year]).to_i
      scope.where(start_date: Date.new(start_year, 1, 1)..Date.new(end_year, 12, 31))

    else
      scope
    end
  end

  # Accepts comma-separated statuses (case-insensitive):
  #   paid, unpaid, overdue
  #
  # Where:
  #   overdue = unpaid AND due_date < today
  def apply_status_filter(scope)
    return scope unless params[:status].present?

    raw_statuses = params[:status].to_s.split(",").map { |s| s.strip.downcase }.uniq

    base_scope = scope
    scopes = []

    if raw_statuses.include?("paid")
      scopes << base_scope.where(status: "paid")
    end

    if raw_statuses.include?("unpaid")
      scopes << base_scope.where(status: "unpaid")
    end

    if raw_statuses.include?("overdue")
      scopes << base_scope.where(status: "unpaid").where("due_date < ?", Date.current)
    end

    return scope if scopes.empty?

    scopes.reduce { |acc, s| acc.or(s) }
  end

  def serialize_billing(b)
    {
      id: b.id,
      start_date: b.start_date,
      end_date: b.end_date,
      due_date: b.due_date,
      amount: b.amount.to_f,
      status: b.status
    }
  end
end
