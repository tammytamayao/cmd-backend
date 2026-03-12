# frozen_string_literal: true

module PaymentGateway
  class Base
    class NotImplementedError < StandardError; end
    class PaymentError < StandardError; end
    class WebhookVerificationError < StandardError; end

    # Create a checkout session that redirects the user to pay via GCash (or other method).
    # Returns: { checkout_id:, checkout_url:, provider: }
    def create_checkout(billing:, payment_method:, success_url:, cancel_url:)
      raise NotImplementedError, "#{self.class.name} must implement #create_checkout"
    end

    # Query the gateway for the current status of a payment.
    # Returns: { status: "completed"|"pending"|"failed"|"expired", raw: <provider_hash> }
    def verify_payment(gateway_payment_id:)
      raise NotImplementedError, "#{self.class.name} must implement #verify_payment"
    end

    # Validate and parse an incoming webhook payload.
    # Returns: { event:, payment_id:, status:, raw: }
    # Raises WebhookVerificationError if signature is invalid.
    def handle_webhook(payload:, headers:)
      raise NotImplementedError, "#{self.class.name} must implement #handle_webhook"
    end

    # List of payment methods this gateway supports.
    # Returns: Array of strings, e.g. ["gcash", "maya", "card", "bank_transfer"]
    def supported_methods
      raise NotImplementedError, "#{self.class.name} must implement #supported_methods"
    end

    # Human-readable provider name for storage.
    def provider_name
      raise NotImplementedError, "#{self.class.name} must implement #provider_name"
    end

    private

    def api_key
      raise NotImplementedError, "#{self.class.name} must implement #api_key"
    end
  end
end
