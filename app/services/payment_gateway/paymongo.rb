# frozen_string_literal: true

require "net/http"
require "json"
require "base64"

module PaymentGateway
  class Paymongo < Base
    API_BASE = "https://api.paymongo.com/v1"

    PAYMENT_METHOD_MAP = {
      "gcash" => "gcash",
      "maya" => "paymaya",
      "card" => "card",
      "grab_pay" => "grab_pay"
    }.freeze

    def create_checkout(billing:, payment_method:, success_url:, cancel_url:)
      method_type = PAYMENT_METHOD_MAP[payment_method.to_s.downcase]
      raise PaymentError, "Unsupported payment method: #{payment_method}" unless method_type

      body = {
        data: {
          attributes: {
            send_email_receipt: false,
            show_description: true,
            show_line_items: true,
            description: "Payment for billing ##{billing.id}",
            line_items: [
              {
                currency: "PHP",
                amount: (billing.amount * 100).to_i, # PayMongo expects cents
                name: "Billing #{billing.start_date} - #{billing.end_date}",
                quantity: 1
              }
            ],
            payment_method_types: [method_type],
            success_url: success_url,
            cancel_url: cancel_url,
            metadata: {
              billing_id: billing.id.to_s,
              subscriber_id: billing.subscriber_id.to_s
            }
          }
        }
      }

      response = post("/checkout_sessions", body)
      attrs = response.dig("data", "attributes")

      {
        checkout_id: response.dig("data", "id"),
        checkout_url: attrs["checkout_url"],
        provider: provider_name
      }
    end

    def verify_payment(gateway_payment_id:)
      response = get("/checkout_sessions/#{gateway_payment_id}")
      attrs = response.dig("data", "attributes")

      payments = attrs["payments"] || []
      latest = payments.last

      status = map_status(attrs["status"], latest)

      {
        status: status,
        gateway_payment_id: latest&.dig("data", "id"),
        raw: response
      }
    end

    def handle_webhook(payload:, headers:)
      # Verify webhook signature
      signature = headers["Paymongo-Signature"] || headers["paymongo-signature"]
      verify_signature!(payload, signature) if webhook_secret.present?

      event = JSON.parse(payload)
      event_type = event.dig("data", "attributes", "type")
      resource = event.dig("data", "attributes", "data")

      checkout_id = resource.dig("attributes", "metadata", "checkout_session_id") ||
                    resource.dig("data", "id")

      {
        event: event_type,
        checkout_id: checkout_id,
        status: map_webhook_status(event_type),
        raw: event
      }
    end

    def supported_methods
      %w[gcash maya card grab_pay]
    end

    def provider_name
      "paymongo"
    end

    private

    def api_key
      ENV.fetch("PAYMONGO_SECRET_KEY") { raise PaymentError, "PAYMONGO_SECRET_KEY not set" }
    end

    def webhook_secret
      ENV["PAYMONGO_WEBHOOK_SECRET"]
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
        errors = parsed["errors"]&.map { |e| e["detail"] }&.join(", ") || response.body
        raise PaymentError, "PayMongo API error: #{errors}"
      end

      parsed
    end

    def map_status(checkout_status, latest_payment)
      if latest_payment
        case latest_payment.dig("data", "attributes", "status")
        when "paid" then "completed"
        when "failed" then "failed"
        else "pending"
        end
      else
        case checkout_status
        when "active" then "pending"
        when "expired" then "expired"
        else "pending"
        end
      end
    end

    def map_webhook_status(event_type)
      case event_type
      when "checkout_session.payment.paid" then "completed"
      when "payment.paid" then "completed"
      when "payment.failed" then "failed"
      else "pending"
      end
    end

    def verify_signature!(payload, signature_header)
      return if signature_header.blank?

      parts = signature_header.split(",").each_with_object({}) do |part, hash|
        key, value = part.split("=", 2)
        hash[key.strip] = value.strip
      end

      timestamp = parts["t"]
      test_sig = parts["te"] # test mode signature
      live_sig = parts["li"] # live mode signature

      signed_payload = "#{timestamp}.#{payload}"
      expected = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, signed_payload)

      unless ActiveSupport::SecurityUtils.secure_compare(expected, test_sig.to_s) ||
             ActiveSupport::SecurityUtils.secure_compare(expected, live_sig.to_s)
        raise WebhookVerificationError, "Invalid PayMongo webhook signature"
      end
    end
  end
end
