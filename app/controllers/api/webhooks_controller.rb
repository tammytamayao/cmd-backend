# frozen_string_literal: true

class Api::WebhooksController < ApplicationController
  # Skip authentication — webhooks come from payment providers, not users.
  skip_before_action :verify_authenticity_token, raise: false

  # POST /api/webhooks/:provider
  # Handles incoming webhook notifications from payment gateways.
  def create
    provider = params[:provider].to_s.downcase

    unless PaymentGateway::Factory.available_providers.include?(provider)
      return render json: { error: "Unknown provider" }, status: :not_found
    end

    gateway = PaymentGateway::Factory.build(provider)
    result = gateway.handle_webhook(
      payload: request.raw_post,
      headers: request.headers
    )

    # Find the payment by checkout_id and update its status
    payment = Payment.find_by(
      gateway_checkout_id: result[:checkout_id],
      gateway_provider: provider
    )

    if payment
      new_status = map_gateway_status(result[:status])
      payment.update(
        status: new_status,
        gateway_payment_id: result[:gateway_payment_id] || payment.gateway_payment_id
      )

      Rails.logger.info("[Webhook] #{provider}: Payment ##{payment.id} updated to #{new_status}")
    else
      Rails.logger.warn("[Webhook] #{provider}: No payment found for checkout #{result[:checkout_id]}")
    end

    # Always respond 200 to acknowledge receipt
    render json: { received: true }, status: :ok
  rescue PaymentGateway::Base::WebhookVerificationError => e
    Rails.logger.error("[Webhook] #{provider}: Verification failed - #{e.message}")
    render json: { error: "Invalid signature" }, status: :unauthorized
  rescue JSON::ParserError => e
    Rails.logger.error("[Webhook] #{provider}: Invalid payload - #{e.message}")
    render json: { error: "Invalid payload" }, status: :bad_request
  end

  private

  def map_gateway_status(status)
    case status
    when "completed" then "Completed"
    when "failed" then "Failed"
    else "Processing"
    end
  end
end
