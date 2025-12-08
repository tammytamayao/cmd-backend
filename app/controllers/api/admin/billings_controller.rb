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

  # GET /api/admin/billings/batch_summary
  #
  # Params:
  #   group: "all" | "specific" (default: "all")
  #   subscriber_ids: array or comma-separated string of subscriber IDs (only for "specific")
  #
  # For now you only care about "all", but this is ready for "specific" later.
  def batch_summary
    Rails.logger.info("[ADMIN] #{current_admin.email} requesting billing batch summary")

    group = params[:group].presence || "all"

    subscribers_scope =
      case group
      when "all"
        Subscriber.all
      when "specific"
        ids_param = params[:subscriber_ids]

        ids = Array(ids_param)
                .flat_map { |v| v.to_s.split(",") }
                .map(&:strip)
                .reject(&:blank?)

        if ids.empty?
          return render json: { error: "subscriber_ids required when group is 'specific'" },
                        status: :unprocessable_entity
        end

        Subscriber.where(id: ids)
      else
        return render json: { error: "Unsupported billing group: #{group}" },
                      status: :unprocessable_entity
      end

    accounts_selected = subscribers_scope.count
    base_amount       = subscribers_scope.sum(:brate).to_f

    render json: {
      group: group,
      accounts_selected: accounts_selected,
      base_amount: base_amount
    }, status: :ok
  end

  # POST /api/admin/billings/batch_create
  #
  # Frontend payload:
  #   {
  #     group: "all",
  #     billing_month: "jan" | "feb" | ... | null,
  #     due_date: "YYYY-MM-DD",
  #     adjustment_per_account: number | null,
  #     adjustment_notes: string | null
  #   }
  #
  # start_date / end_date:
  #   - If billing_month is provided, use first/last day of that month in the current year
  #   - If not, leave start_date/end_date as nil
  #
  # adjustment:
  #   - If no adjustment_per_account is passed, store NULL in adjustment
  #   - amount always = brate + (adjustment_per_account || 0)
  def batch_create
    Rails.logger.info("[ADMIN] #{current_admin.email} creating batch billings")

    group = params[:group].presence || "all"

    subscribers_scope =
      case group
      when "all"
        Subscriber.all
      when "specific"
        ids_param = params[:subscriber_ids]

        ids = Array(ids_param)
                .flat_map { |v| v.to_s.split(",") }
                .map(&:strip)
                .reject(&:blank?)

        if ids.empty?
          return render json: { error: "subscriber_ids required when group is 'specific'" },
                        status: :unprocessable_entity
        end

        Subscriber.where(id: ids)
      else
        return render json: { error: "Unsupported billing group: #{group}" },
                      status: :unprocessable_entity
      end

    accounts_selected = subscribers_scope.count
    if accounts_selected.zero?
      return render json: { error: "No subscribers found for group '#{group}'" },
                    status: :unprocessable_entity
    end

    if params[:due_date].blank?
      return render json: { error: "due_date is required" },
                    status: :unprocessable_entity
    end

    begin
      due_date = Date.parse(params[:due_date])
    rescue ArgumentError
      return render json: { error: "Invalid due_date" }, status: :unprocessable_entity
    end

    # Derive start_date and end_date from billing_month (current year)
    billing_month = params[:billing_month].presence
    start_date = nil
    end_date   = nil

    if billing_month.present?
      month_map = {
        "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
        "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8,
        "sep" => 9, "oct" => 10, "nov" => 11, "dec" => 12
      }

      month_num = month_map[billing_month.to_s.downcase]
      if month_num
        year       = Date.current.year
        start_date = Date.new(year, month_num, 1)
        end_date   = start_date.end_of_month
      end
    end

    # adjustment_per_account comes from your React page as the sum of item.amount per account
    adjustment_per_account =
      if params.key?(:adjustment_per_account) && params[:adjustment_per_account].present?
        BigDecimal(params[:adjustment_per_account].to_s)
      else
        nil  # store NULL in the adjustment column
      end

    # Amount should still be brate + (adjustment_per_account || 0)
    adjustment_for_amount = adjustment_per_account || 0.to_d

    adjustment_notes = params[:adjustment_notes].presence

    created_count = 0

    Billing.transaction do
      subscribers_scope.find_each do |subscriber|
        base   = (subscriber.brate || 0).to_d
        amount = base + adjustment_for_amount

        Billing.create!(
          subscriber:       subscriber,
          start_date:       start_date,
          end_date:         end_date,
          due_date:         due_date,
          status:           "open",
          amount:           amount,
          adjustment:       adjustment_per_account,
          adjustment_notes: adjustment_notes
        )

        created_count += 1
      end
    end

    render json: {
      group: group,
      accounts_selected: accounts_selected,
      created_count: created_count
    }, status: :created
  end

  private

  def serialize_billing(billing)
    subscriber = billing.subscriber

    {
      id:         billing.id,
      start_date: billing.start_date,
      end_date:   billing.end_date,
      amount:     billing.amount.to_f,
      adjustment: billing.adjustment&.to_f,        # NEW
      adjustment_notes: billing.adjustment_notes,  # NEW
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
      :amount,
      :adjustment,
      :adjustment_notes
    )
  end
end
