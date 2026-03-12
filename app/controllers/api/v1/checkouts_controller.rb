# frozen_string_literal: true

class Api::V1::CheckoutsController < ApplicationController
  before_action :authenticate_request!

  # POST /api/v1/checkouts
  # Creates a checkout session with the configured payment gateway.
  # Params:
  #   - billing_id (required)
  #   - payment_method: "gcash" | "maya" | "card" | "grab_pay" (required)
  #   - success_url (required) - where to redirect after successful payment
  #   - cancel_url (required) - where to redirect if payment is cancelled
  def create
    billing = current_subscriber.billings.find_by(id: params[:billing_id])
    return render json: { error: "Billing not found" }, status: :not_found unless billing

    payment_method = params[:payment_method].to_s.downcase
    success_url = params[:success_url]
    cancel_url = params[:cancel_url]

    if payment_method.blank?
      return render json: { error: "payment_method is required" }, status: :bad_request
    end

    if success_url.blank? || cancel_url.blank?
      return render json: { error: "success_url and cancel_url are required" }, status: :bad_request
    end

    gateway = PaymentGateway::Factory.current

    unless gateway.supported_methods.include?(payment_method)
      return render json: {
        error: "Payment method '#{payment_method}' is not supported by #{gateway.provider_name}",
        supported_methods: gateway.supported_methods
      }, status: :unprocessable_entity
    end

    result = gateway.create_checkout(
      billing: billing,
      payment_method: payment_method,
      success_url: success_url,
      cancel_url: cancel_url
    )

    # Create a pending payment record linked to this checkout
    method_label = normalize_method_label(payment_method)
    payment = Payment.new(
      billing_id: billing.id,
      payment_date: Time.zone.today,
      amount: billing.amount,
      status: "Processing",
      payment_method: method_label,
      attachment: "gateway://#{result[:provider]}/#{result[:checkout_id]}",
      gateway_provider: result[:provider],
      gateway_checkout_id: result[:checkout_id]
    )

    if payment.save
      render json: {
        data: {
          checkout_url: result[:checkout_url],
          checkout_id: result[:checkout_id],
          provider: result[:provider],
          payment_id: payment.id
        }
      }, status: :created
    else
      render json: { error: payment.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue PaymentGateway::Base::PaymentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/checkouts/:id/verify
  # Check the current status of a checkout/payment with the gateway.
  def verify
    payment = Payment.joins(billing: :subscriber)
                     .where(billings: { subscriber_id: current_subscriber.id })
                     .find_by(gateway_checkout_id: params[:id])

    return render json: { error: "Checkout not found" }, status: :not_found unless payment

    gateway = PaymentGateway::Factory.build(payment.gateway_provider)
    result = gateway.verify_payment(gateway_payment_id: payment.gateway_checkout_id)

    # Update payment status based on gateway response
    new_status = map_gateway_status(result[:status])
    if payment.status != new_status
      payment.update(
        status: new_status,
        gateway_payment_id: result[:gateway_payment_id]
      )
    end

    render json: {
      data: {
        payment_id: payment.id,
        status: payment.status,
        gateway_status: result[:status],
        provider: payment.gateway_provider
      }
    }
  rescue PaymentGateway::Base::PaymentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def normalize_method_label(method)
    case method
    when "gcash" then "GCash"
    when "maya" then "Maya"
    when "card" then "Card"
    when "grab_pay" then "GrabPay"
    when "bank_transfer" then "Bank Transfer"
    else method.titleize
    end
  end

  def map_gateway_status(status)
    case status
    when "completed" then "Completed"
    when "failed" then "Failed"
    else "Processing"
    end
  end
end
