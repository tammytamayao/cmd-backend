# frozen_string_literal: true

module PaymentGateway
  class Factory
    PROVIDERS = {
      "paymongo" => "PaymentGateway::Paymongo",
      "xendit" => "PaymentGateway::Xendit",
      "dragonpay" => "PaymentGateway::Dragonpay"
    }.freeze

    class << self
      # Returns the currently configured gateway adapter instance.
      def current
        build(current_provider)
      end

      # Build a specific provider adapter by name.
      def build(provider)
        klass_name = PROVIDERS[provider.to_s.downcase]
        raise ArgumentError, "Unknown payment provider: #{provider}. Valid: #{PROVIDERS.keys.join(', ')}" unless klass_name

        klass_name.constantize.new
      end

      # The active provider name from env config.
      def current_provider
        ENV.fetch("PAYMENT_GATEWAY", "paymongo").downcase
      end

      def available_providers
        PROVIDERS.keys
      end
    end
  end
end
