class Api::V1::SessionsController < ApplicationController
  before_action :authenticate_request!, only: :show

  def create
    normalized = Subscriber.normalize_raw_phone(params[:phone_number])
    subscriber = Subscriber.find_by(phone_number: normalized)

    if subscriber&.authenticate(params[:password])
      token = JsonWebToken.encode({ sub: subscriber.id, type: "subscriber" })

      render json: {
        token: token,
        subscriber: {
          id: subscriber.id,
          first_name: subscriber.first_name,
          last_name: subscriber.last_name,
          phone_number: subscriber.phone_number,
          plan: subscriber.plan,
          brate: subscriber.brate,
          requires_password_change: subscriber.requires_password_change
        }
      }, status: :created
    else
      render json: { error: "Invalid phone or password" }, status: :unauthorized
    end
  end

  def show
    s = current_subscriber
    latest_billing = s.billings.order(start_date: :desc).first

    render json: {
      id: s.id,
      zone: s.zone,
      first_name: s.first_name,
      last_name: s.last_name,
      full_name: "#{s.first_name} #{s.last_name}",
      phone_number: s.phone_number,
      date_installed: s.date_installed,
      plan: s.plan,
      brate: s.brate,
      package: s.package,
      package_speed: s.package_speed,
      serial_number: s.serial_number,

      # ✅ now comes from latest billing
      amount_due: latest_billing&.amount&.to_f || 0,
      due_on: latest_billing&.due_date,
      latest_billing: latest_billing ? {
        id: latest_billing.id,
        status: latest_billing.status
      } : nil
    }
  end

  def destroy
    head :no_content
  end
end
