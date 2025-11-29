class ApplicationController < ActionController::API
  private

  # ========= SUBSCRIBER AUTH (api/v1) =========
  def authenticate_request!
    header  = request.headers["Authorization"].to_s
    token   = header.split(" ").last
    payload = JsonWebToken.decode(token) || {}

    token_type = payload["type"] || payload[:type]
    # Allow only subscriber tokens (or no type for older tokens)
    if token_type.present? && token_type != "subscriber"
      return unauthorized!
    end

    sub_id = payload["sub"] || payload[:sub]
    @current_subscriber = Subscriber.find_by(id: sub_id)

    return unauthorized! unless @current_subscriber
  rescue StandardError
    unauthorized!
  end

  def current_subscriber
    @current_subscriber
  end

  # ========= ADMIN AUTH (api/admin) =========
  def authenticate_admin!
    header  = request.headers["Authorization"].to_s
    token   = header.split(" ").last
    payload = JsonWebToken.decode(token) || {}

    token_type = payload["type"] || payload[:type]
    return unauthorized! unless token_type == "admin"

    admin_id = payload["sub"] || payload[:sub]
    @current_admin = AdminUser.find_by(id: admin_id)

    return unauthorized! unless @current_admin
  rescue StandardError
    unauthorized!
  end

  def current_admin
    @current_admin
  end

# ========= COMMON =========
  def unauthorized!
    render json: { error: "Unauthorized" }, status: :unauthorized
    nil
  end
end
