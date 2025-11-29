# app/controllers/api/admin/sessions_controller.rb
class Api::Admin::SessionsController < ApplicationController
  # POST /api/admin/login
  def create
    admin = AdminUser.find_by("LOWER(email) = ?", params[:email].to_s.downcase)

    if admin&.authenticate(params[:password])
      token = JsonWebToken.encode({ sub: admin.id, type: "admin", role: admin.role })

      render json: {
        token: token,
        admin: {
          id: admin.id,
          email: admin.email,
          role: admin.role
        }
      }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end
end
