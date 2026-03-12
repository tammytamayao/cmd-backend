# frozen_string_literal: true

require "net/http"
require "json"
require "base64"

module PaymentGateway
  class Xendit < Base
    API_BASE = "https://api.xendit.co"

    PAYMENT_METHOD_MAP = {
      "gcash" => "GCASH",
      "maya" => "PAYMAYA",
      "card" => "CREDIT_CARD",
      "grab_pay" => "GRABPAY",
      "bank_transfer" => "DIRECT_DEBIT"
    }.freeze

    def create_checkout(billing:, payment_method:, success_url:, cancel_url:)
      channel = PAYMENT_METHOD_MAP[payment_method.to_s.downcase]
      raise PaymentError, "Unsupported payment method: #{payment_method}" unless channel

      body = {
        external_id: "billing-#{billing.id}-#{Time.current.to_i}",
        amount: billing.amount.to_f,
        currency: "PHP",
        payment_method: {
          type: "EWALLET",
          ewallet: {
            channel_code: channel,
            channel_properties: {
              success_redirect_url: success_url,
              failure_redirect_url: cancel_url
            }
          },
          reusability: "ONE_TIME_USE"
        },
        metadata: {
          billing_id: billing.id.to_s,
          subscriber_id: billing.subscriber_id.to_s
        }
      }

      response = post("/v2/payment_requests", body)

      checkout_url = response.dig("actions", 0, "url") ||
                     response.dig("actions", 0, "mobile_web_checkout_url")

      {
        checkout_id: response["id"],
        checkout_url: checkout_url,
        provider: provider_name
      }
    end

    def verify_payment(gateway_payment_id:)
      response = get("/v2/payment_requests/#{gateway_payment_id}")

      {
        status: map_status(response["status"]),
        gateway_payment_id: response["id"],
        raw: response
      }
    end

    def handle_webhook(payload:, headers:)
      callback_token = headers["X-Callback-Token"] || headers["x-callback-token"]
      verify_callback_token!(callback_token) if webhook_token.present?

      event = JSON.parse(payload)

      {
        event: event["event"],
        checkout_id: event.dig("data", "id") || event["id"],
        status: map_webhook_status(event["event"] || event["status"]),
        raw: event
      }
    end

    def supported_methods
      %w[gcash maya card grab_pay bank_transfer]
    end

    def provider_name
      "xendit"
    end

    private

    def api_key
      ENV.fetch("XENDIT_SECRET_KEY") { raise PaymentError, "XENDIT_SECRET_KEY not set" }
    end

    def webhook_token
      ENV["XENDIT_WEBHOOK_TOKEN"]
    end

    def auth_header
      "Basic #{Base64.strict_encode64("#{api_key}:")}"
    end

    def post(path, body)
      uri = URI("#{API_BASE}#{path}")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = auth_header
      req["Content-Type"] = "application/json"
      req.body = body.to_json

      execute(uri, req)
    end

    def get(path)
      uri = URI("#{API_BASE}#{path}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = auth_header

      execute(uri, req)
    end

    def execute(uri, req)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      parsed = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        error_msg = parsed["message"] || parsed["error_code"] || response.body
        raise PaymentError, "Xendit API error: #{error_msg}"
      end

      parsed
    end

    def map_status(status)
      case status&.upcase
      when "SUCCEEDED", "COMPLETED", "PAID" then "completed"
      when "FAILED" then "failed"
      when "EXPIRED" then "expired"
      else "pending"
      end
    end

    def map_webhook_status(event_or_status)
      case event_or_status
      when "payment.succeeded", "SUCCEEDED", "COMPLETED", "PAID" then "completed"
      when "payment.failed", "FAILED" then "failed"
      else "pending"
      end
    end

    def verify_callback_token!(token)
      unless ActiveSupport::SecurityUtils.secure_compare(webhook_token, token.to_s)
        raise WebhookVerificationError, "Invalid Xendit callback token"
      end
    end
  end
end
