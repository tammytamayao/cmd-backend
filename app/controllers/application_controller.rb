class ApplicationController < ActionController::API
  private

  def authenticate_request!
    header  = request.headers["Authorization"].to_s
    token   = header.split(" ").last
    payload = JsonWebToken.decode(token) || {}

    sub_id = payload["sub"] || payload[:sub]
    @current_subscriber = Subscriber.find_by(id: sub_id)

    unless @current_subscriber
      render json: { error: "Unauthorized" }, status: :unauthorized
      return
    end
  rescue StandardError
    render json: { error: "Unauthorized" }, status: :unauthorized
    return
  end

  def current_subscriber
    @current_subscriber
  end
end
