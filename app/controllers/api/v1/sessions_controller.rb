class Api::V1::SessionsController < ApplicationController
  before_action :authenticate_request!, only: :show

  def create
    subscriber = Subscriber.find_by(serial_number: params[:serial_number])

    if subscriber&.authenticate(params[:password])
      token = JsonWebToken.encode({ sub: subscriber.id, type: "subscriber" })

      render json: {
        token: token,
        subscriber: {
          id: subscriber.id,
          first_name: subscriber.first_name,
          last_name: subscriber.last_name,
          serial_number: subscriber.serial_number,
          plan: subscriber.plan,
          brate: subscriber.brate,
          requires_password_change: subscriber.requires_password_change
        }
      }, status: :created
    else
      render json: { error: "Invalid subscriber number or password" }, status: :unauthorized
    end
  end

  def show
    s = current_subscriber

    latest_billing = s.billings.order(start_date: :desc).first

    unpaid_billings = s.billings.where.not(status: "paid")
    total_amount_due = unpaid_billings.sum(:amount).to_f

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
      amount_due: total_amount_due,
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
