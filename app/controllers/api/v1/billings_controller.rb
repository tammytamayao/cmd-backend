class Api::V1::BillingsController < ApplicationController
  before_action :authenticate_request!

  # GET /api/v1/billings
  # Optional query params:
  #   ?year=2025  OR  ?start_year=2024&end_year=2025
  #   ?status=paid|unpaid|overdue
  #   ?page=1&per_page=12
  def index
    billings = current_subscriber
                 .billings
                 .includes(:payments)
                 .order(start_date: :desc)

    # --- Filter by year or range ---
    if params[:year].present?
      y = params[:year].to_i
      billings = billings.where(start_date: Date.new(y, 1, 1)..Date.new(y, 12, 31))
    else
      start_year = (params[:start_year] || 2024).to_i
      end_year   = (params[:end_year]   || 2025).to_i
      billings = billings.where(start_date: Date.new(start_year, 1, 1)..Date.new(end_year, 12, 31))
    end

    # --- Optional status filter ---
    if params[:status].present?
      # Split by comma and match case-insensitively
      statuses = params[:status].split(",").map(&:strip).map(&:capitalize)
      billings = billings.where(status: statuses)
    end

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
