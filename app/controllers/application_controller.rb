class ApplicationController < ActionController::API
  private

  def authenticate_request!
    header = request.headers["Authorization"].to_s
    token  = header.split(" ").last
    payload = JsonWebToken.decode(token)
    @current_subscriber = payload && Subscriber.find_by(id: payload[:sub])
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_subscriber
  end

  def current_subscriber
    @current_subscriber
  end
end
