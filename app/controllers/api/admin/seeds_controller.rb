# app/controllers/api/admin/seeds_controller.rb
class Api::Admin::SeedsController < ApplicationController
  before_action :authenticate_admin!

  # POST /api/admin/seed_subscribers
  # Seeds subscriber data without destroying existing records
  def seed_subscribers
    Rails.logger.info("[ADMIN] #{current_admin.email} seeding subscribers")

    begin
      load Rails.root.join("db/seeds_subscribers.rb")
      render json: {
        message: "Subscribers seeded successfully",
        count: Subscriber.count
      }, status: :ok
    rescue => e
      Rails.logger.error("[ADMIN] Seed subscribers failed: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /api/admin/reset_database
  # Destroys all data and reseeds (requires confirmation parameter)
  def reset_database
    Rails.logger.info("[ADMIN] #{current_admin.email} attempting database reset")

    # Require explicit confirmation
    unless params[:confirm] == "RESET"
      return render json: {
        error: 'Missing confirmation. Send { "confirm": "RESET" } to proceed.'
      }, status: :bad_request
    end

    begin
      Rails.logger.warn("[ADMIN] #{current_admin.email} resetting database!")

      Payment.destroy_all
      Billing.destroy_all
      Subscriber.destroy_all

      load Rails.root.join("db/seeds_admins.rb")
      load Rails.root.join("db/seeds_subscribers.rb")

      render json: {
        message: "Database reset and reseeded successfully",
        subscribers: Subscriber.count,
        billings: Billing.count,
        payments: Payment.count
      }, status: :ok
    rescue => e
      Rails.logger.error("[ADMIN] Database reset failed: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /api/admin/delete_all_subscribers
  # Destroys all subscriber data without reseeding (requires confirmation parameter)
  def delete_all_subscribers
    Rails.logger.info("[ADMIN] #{current_admin.email} attempting to delete all subscribers")

    # Require explicit confirmation
    unless params[:confirm] == "DELETE"
      return render json: {
        error: 'Missing confirmation. Send { "confirm": "DELETE" } to proceed.'
      }, status: :bad_request
    end

    begin
      Rails.logger.warn("[ADMIN] #{current_admin.email} deleting all subscribers!")

      Payment.destroy_all
      Billing.destroy_all
      Subscriber.destroy_all

      render json: {
        message: "All subscribers, billings, and payments deleted successfully",
        subscribers: Subscriber.count,
        billings: Billing.count,
        payments: Payment.count
      }, status: :ok
    rescue => e
      Rails.logger.error("[ADMIN] Delete all subscribers failed: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end
  end
end
