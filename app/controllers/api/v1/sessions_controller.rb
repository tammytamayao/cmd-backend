class Api::V1::SessionsController < ApplicationController
  before_action :authenticate_request!, only: :show

  def create
    digits = params[:phone_number].to_s.gsub(/\D/, "")
    phone  = digits.start_with?("+") ? digits : "+#{digits}"
    subscriber = Subscriber.find_by(phone_number: phone)

    if subscriber&.authenticate(params[:password])
      token = JsonWebToken.encode({ sub: subscriber.id })
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

  # GET /api/v1/session/me
  def show
    s = current_subscriber
    render json: {
      id: s.id,
      first_name: s.first_name,
      last_name: s.last_name,
      full_name: "#{s.first_name} #{s.last_name}",
      phone_number: s.phone_number,
      plan: s.plan,
      brate: s.brate,
      package_speed: s.package_speed,
      serial_number: s.serial_number,
      amount_due: s.brate,
      due_on: Date.today.end_of_month
    }
  end

  def destroy
    head :no_content
  end
end
