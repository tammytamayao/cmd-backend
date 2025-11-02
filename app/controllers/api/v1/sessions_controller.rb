class Api::V1::SessionsController < ApplicationController
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

    # DELETE /api/v1/sessions (optional)
    def destroy
    head :no_content
    end

end
