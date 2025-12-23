# app/controllers/api/admin/billings_controller.rb
class Api::Admin::BillingsController < ApplicationController
  before_action :authenticate_admin!

  PER_PAGE = 10

  # GET /api/admin/billings
  def index
    Rails.logger.info("[ADMIN] #{current_admin.email} listing billings")

    billings = Billing
      .includes(:subscriber)
      .joins(:subscriber)
      .order(start_date: :desc, id: :desc)

    billings = billings.where(subscriber_id: params[:subscriber_id]) if params[:subscriber_id].present?
    billings = apply_status_filter(billings)
    billings = apply_search(billings)

    page, per_page = normalize_pagination
    total = billings.count
    billings = billings.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: billings.map { |b| serialize_billing(b) },
      meta: pagination_meta(page, per_page, total)
    }
  end

  # GET /api/admin/billings/:id
  def show
    Rails.logger.info("[ADMIN] #{current_admin.email} fetching billing #{params[:id]}")

    billing = Billing.includes(:subscriber).find_by(id: params[:id])
    return render json: { error: "Billing not found" }, status: :not_found unless billing

    render json: { data: serialize_billing(billing) }, status: :ok
  end

  # POST /api/admin/billings
  def create
    Rails.logger.info("[ADMIN] #{current_admin.email} creating single billing")

    p = billing_create_params

    subscriber = Subscriber.find_by(id: p[:subscriber_id])
    return render json: { error: "Subscriber not found" }, status: :not_found unless subscriber

    begin
      start_date = parse_date!(p[:start_date], "start_date")
      end_date   = parse_date!(p[:end_date], "end_date")
      due_date   = parse_date!(p[:due_date], "due_date")
    rescue DateParseError => e
      return render json: { error: e.message }, status: :unprocessable_entity
    end

    if start_date > end_date
      return render json: { error: "start_date must be on or before end_date" }, status: :unprocessable_entity
    end

    amount = parse_amount(p[:amount])
    return render json: { error: "amount must be greater than 0" }, status: :unprocessable_entity if amount.nil? || amount <= 0

    status = normalize_status(p[:status])

    adjustment = parse_decimal(p[:adjustment]) # optional

    billing = Billing.new(
      subscriber: subscriber,
      start_date: start_date,
      end_date: end_date,
      due_date: due_date,
      amount: amount,
      status: status,
      adjustment: adjustment,
      adjustment_notes: p[:adjustment_notes].presence
    )

    if billing.save
      render json: { data: serialize_billing(billing) }, status: :created
    else
      render json: { error: "Validation failed", details: billing.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/admin/billings/:id
  def update
    Rails.logger.info("[ADMIN] #{current_admin.email} updating billing #{params[:id]}")

    billing = Billing.find_by(id: params[:id])
    return render json: { error: "Billing not found" }, status: :not_found unless billing

    payload = billing_params.to_h

    # normalize status if present
    payload[:status] = normalize_status(payload[:status]) if payload.key?(:status)

    if billing.update(payload)
      render json: { data: serialize_billing(billing) }, status: :ok
    else
      render json: { error: "Validation failed", details: billing.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/admin/billings/batch_summary
  def batch_summary
    Rails.logger.info("[ADMIN] #{current_admin.email} requesting billing batch summary")

    group = (params[:group].presence || "all").to_s
    subscribers_scope = resolve_subscribers_scope(group)
    return subscribers_scope if performed?

    billing_start = params[:billing_start].presence
    billing_end   = params[:billing_end].presence

    start_date = nil
    end_date   = nil
    existing_count = nil

    if billing_start.present? || billing_end.present?
      begin
        start_date, end_date = parse_billing_range!(billing_start, billing_end)
      rescue DateParseError => e
        return render json: { error: e.message }, status: :unprocessable_entity
      end

      existing_count = Billing.where(
        subscriber_id: subscribers_scope.select(:id),
        start_date: start_date,
        end_date: end_date
      ).count
    end

    accounts_selected = subscribers_scope.count
    base_amount       = subscribers_scope.sum(:brate).to_f

    render json: {
      group: group,
      accounts_selected: accounts_selected,
      base_amount: base_amount,
      billing_start: start_date,
      billing_end: end_date,
      existing_count: existing_count
    }, status: :ok
  end

  # POST /api/admin/billings/batch_create
  def batch_create
    Rails.logger.info("[ADMIN] #{current_admin.email} creating batch billings")

    group = (params[:group].presence || "all").to_s
    subscribers_scope = resolve_subscribers_scope(group)
    return subscribers_scope if performed?

    accounts_selected = subscribers_scope.count
    return render json: { error: "No subscribers found for group '#{group}'" }, status: :unprocessable_entity if accounts_selected.zero?

    # due_date required
    return render json: { error: "due_date is required" }, status: :unprocessable_entity if params[:due_date].blank?

    begin
      due_date = parse_date!(params[:due_date], "due_date")
    rescue DateParseError => e
      return render json: { error: e.message }, status: :unprocessable_entity
    end

    # billing range: option B or legacy
    begin
      start_date, end_date = resolve_batch_period!
    rescue DateParseError => e
      return render json: { error: e.message }, status: :unprocessable_entity
    end

    adjustment_per_account = parse_decimal(params[:adjustment_per_account]) # optional
    adjustment_for_amount  = adjustment_per_account || 0.to_d
    adjustment_notes       = params[:adjustment_notes].presence

    created_count = 0
    skipped_count = 0

    Billing.transaction do
      subscribers_scope.find_each do |subscriber|
        base   = (subscriber.brate || 0).to_d
        amount = base + adjustment_for_amount

        begin
          Billing.create!(
            subscriber: subscriber,
            start_date: start_date,
            end_date: end_date,
            due_date: due_date,
            status: "unpaid",
            amount: amount,
            adjustment: adjustment_per_account,
            adjustment_notes: adjustment_notes
          )
          created_count += 1
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
          skipped_count += 1
        end
      end
    end

    render json: {
      group: group,
      accounts_selected: accounts_selected,
      created_count: created_count,
      skipped_count: skipped_count
    }, status: :created
  end

  private

  # ---------- params ----------
  def billing_params
    params.permit(:status, :start_date, :end_date, :due_date, :amount, :adjustment, :adjustment_notes)
  end

  def billing_create_params
    # require subscriber_id + all required fields; still permit optional fields
    params.permit(:subscriber_id, :start_date, :end_date, :due_date, :amount, :status, :adjustment, :adjustment_notes)
  end

  # ---------- helpers ----------
  def normalize_pagination
    page = (params[:page].presence || 1).to_i
    per_page = (params[:per_page].presence || PER_PAGE).to_i
    per_page = PER_PAGE if per_page <= 0
    page = 1 if page <= 0
    [page, per_page]
  end

  def pagination_meta(page, per_page, total)
    {
      page: page,
      per_page: per_page,
      total: total,
      total_pages: (total / per_page.to_f).ceil
    }
  end

  def apply_search(scope)
    return scope unless params[:q].present?

    q = params[:q].to_s.strip.downcase
    escaped = ActiveRecord::Base.sanitize_sql_like(q)
    like = "%#{escaped}%"

    scope.where(
      <<~SQL,
        LOWER(CAST(billings.id AS TEXT)) LIKE :like
        OR LOWER(billings.status) LIKE :like
        OR LOWER(CAST(billings.start_date AS TEXT)) LIKE :like
        OR LOWER(CAST(billings.end_date AS TEXT)) LIKE :like
        OR LOWER(CAST(billings.due_date AS TEXT)) LIKE :like
        OR LOWER(subscribers.serial_number) LIKE :like
        OR LOWER(subscribers.first_name) LIKE :like
        OR LOWER(subscribers.last_name) LIKE :like
        OR LOWER(subscribers.zone) LIKE :like
      SQL
      like: like
    )
  end

  def normalize_status(value)
    v = value.to_s.strip.downcase
    v == "paid" ? "paid" : "unpaid"
  end

  def parse_amount(value)
    parse_decimal(value)
  end

  def parse_decimal(value)
    return nil if value.nil?
    str = value.to_s.strip
    return nil if str.blank?

    BigDecimal(str)
  rescue ArgumentError
    nil
  end

  class DateParseError < StandardError; end

  def parse_date!(value, field_name)
    str = value.to_s.strip
    raise DateParseError, "Missing #{field_name}" if str.blank?

    Date.parse(str)
  rescue ArgumentError
    raise DateParseError, "Invalid #{field_name} (expected YYYY-MM-DD)"
  end

  def parse_billing_range!(billing_start, billing_end)
    if billing_start.blank? || billing_end.blank?
      raise DateParseError, "billing_start and billing_end must both be provided"
    end

    start_date = Date.parse(billing_start)
    end_date   = Date.parse(billing_end)

    raise DateParseError, "billing_start must be on or before billing_end" if start_date > end_date

    [start_date, end_date]
  rescue ArgumentError
    raise DateParseError, "Invalid billing_start or billing_end"
  end

  def resolve_batch_period!
    billing_start = params[:billing_start].presence
    billing_end   = params[:billing_end].presence

    if billing_start.present? || billing_end.present?
      return parse_billing_range!(billing_start, billing_end)
    end

    # Legacy fallback
    billing_month = params[:billing_month].presence
    raise DateParseError, "billing_start and billing_end are required" if billing_month.blank?

    month_map = {
      "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
      "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8,
      "sep" => 9, "oct" => 10, "nov" => 11, "dec" => 12
    }

    month_num = month_map[billing_month.to_s.downcase]
    raise DateParseError, "Invalid billing_month" unless month_num

    year = Date.current.year
    start_date = Date.new(year, month_num, 1)
    end_date   = start_date.end_of_month

    [start_date, end_date]
  end

  def resolve_subscribers_scope(group)
    case group
    when "all"
      Subscriber.all
    when "specific"
      ids = parse_ids(params[:subscriber_ids])

      if ids.empty?
        render json: { error: "subscriber_ids required when group is 'specific'" }, status: :unprocessable_entity
        return Subscriber.none
      end

      Subscriber.where(id: ids)
    else
      render json: { error: "Unsupported billing group: #{group}" }, status: :unprocessable_entity
      Subscriber.none
    end
  end

  def parse_ids(ids_param)
    Array(ids_param)
      .flat_map { |v| v.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)
  end

  # ---------- existing methods you already had ----------
  def serialize_billing(billing)
    subscriber = billing.subscriber

    {
      id: billing.id,
      start_date: billing.start_date,
      end_date: billing.end_date,
      amount: billing.amount.to_f,
      adjustment: billing.adjustment&.to_f,
      adjustment_notes: billing.adjustment_notes,
      due_date: billing.due_date,
      status: billing.status,
      created_at: billing.created_at.as_json,
      updated_at: billing.updated_at.as_json,
      subscriber_id: billing.subscriber_id,
      subscriber: {
        id: subscriber&.id,
        serial_number: subscriber&.serial_number,
        first_name: subscriber&.first_name,
        last_name: subscriber&.last_name,
        phone_number: subscriber&.phone_number,
        package: subscriber&.package,
        plan: subscriber&.plan,
        zone: subscriber&.zone
      }
    }
  end

  def apply_status_filter(scope)
    return scope unless params[:status].present?

    raw = params[:status].to_s.split(",").map { |s| s.strip.downcase }.uniq
    scopes = []

    scopes << scope.where(status: "paid") if raw.include?("paid")
    scopes << scope.where(status: "unpaid") if raw.include?("unpaid")
    scopes << scope.where(status: "unpaid").where("due_date < ?", Date.current) if raw.include?("overdue")

    return scope if scopes.empty?

    scopes.reduce { |acc, s| acc.or(s) }
  end
end
