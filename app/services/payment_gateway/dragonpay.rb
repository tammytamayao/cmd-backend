# frozen_string_literal: true

require "net/http"
require "json"
require "digest"

module PaymentGateway
  class Dragonpay < Base
    PAYMENT_METHOD_MAP = {
      "gcash" => "GCSH",
      "maya" => "PYMY",
      "grab_pay" => "GRPY",
      "bank_transfer" => "BAYD",
      "otc_7eleven" => "7ELV",
      "otc_cebuana" => "CEBL"
    }.freeze

    def create_checkout(billing:, payment_method:, success_url:, cancel_url:)
      proc_id = PAYMENT_METHOD_MAP[payment_method.to_s.downcase]
      raise PaymentError, "Unsupported payment method: #{payment_method}" unless proc_id

      txn_id = "CMD-#{billing.id}-#{Time.current.to_i}"
      amount = format("%.2f", billing.amount.to_f)
      description = "Payment for billing ##{billing.id}"

      # Build the digest for authentication: merchantid|txnid|amount|ccy|description|email|password
      digest_string = "#{merchant_id}|#{txn_id}|#{amount}|PHP|#{description}|#{merchant_email}|#{api_key}"
      digest = Digest::SHA1.hexdigest(digest_string)

      params = {
        merchantid: merchant_id,
        txnid: txn_id,
        amount: amount,
        ccy: "PHP",
        description: description,
        email: merchant_email,
        digest: digest,
        param1: billing.id.to_s,
        param2: billing.subscriber_id.to_s,
        procid: proc_id
      }

      checkout_url = "#{api_base}/Pay.aspx?#{URI.encode_www_form(params)}"

      {
        checkout_id: txn_id,
        checkout_url: checkout_url,
        provider: provider_name
      }
    end

    def verify_payment(gateway_payment_id:)
      txn_id = gateway_payment_id
      digest_string = "#{merchant_id}|#{txn_id}|#{api_key}"
      digest = Digest::SHA1.hexdigest(digest_string)

      uri = URI("#{api_base}/MerchantRequest.aspx")
      uri.query = URI.encode_www_form(
        op: "GETSTATUS",
        merchantid: merchant_id,
        merchantpwd: api_key,
        txnid: txn_id,
        digest: digest
      )

      response = Net::HTTP.get_response(uri)
      status_code = response.body.strip

      {
        status: map_status(status_code),
        gateway_payment_id: txn_id,
        raw: { status_code: status_code, body: response.body }
      }
    end

    def handle_webhook(payload:, headers:)
      # DragonPay sends postback via GET/POST with: txnid, refno, status, message, digest
      params = if payload.is_a?(String)
                 JSON.parse(payload)
               else
                 payload
               end

      txn_id = params["txnid"]
      ref_no = params["refno"]
      status = params["status"]
      message = params["message"]
      digest = params["digest"]

      # Verify digest: SHA1(txnid|refno|status|message|password)
      if api_key.present?
        expected = Digest::SHA1.hexdigest("#{txn_id}|#{ref_no}|#{status}|#{message}|#{api_key}")
        unless ActiveSupport::SecurityUtils.secure_compare(expected, digest.to_s)
          raise WebhookVerificationError, "Invalid DragonPay digest"
        end
      end

      {
        event: "payment.#{status == 'S' ? 'success' : 'update'}",
        checkout_id: txn_id,
        status: map_status(status),
        raw: params
      }
    end

    def supported_methods
      %w[gcash maya grab_pay bank_transfer otc_7eleven otc_cebuana]
    end

    def provider_name
      "dragonpay"
    end

    private

    def api_key
      ENV.fetch("DRAGONPAY_PASSWORD") { raise PaymentError, "DRAGONPAY_PASSWORD not set" }
    end

    def merchant_id
      ENV.fetch("DRAGONPAY_MERCHANT_ID") { raise PaymentError, "DRAGONPAY_MERCHANT_ID not set" }
    end

    def merchant_email
      ENV.fetch("DRAGONPAY_EMAIL", "noreply@example.com")
    end

    def api_base
      if ENV["DRAGONPAY_TEST_MODE"] == "true"
        "https://test.dragonpay.ph"
      else
        "https://gw.dragonpay.ph"
      end
    end

    def map_status(status_code)
      case status_code.to_s.upcase
      when "S" then "completed"
      when "F" then "failed"
      when "V" then "expired"      # voided
      when "R" then "refunded"
      when "P", "U", "H" then "pending" # pending, unknown, held
      else "pending"
      end
    end
  end
end
