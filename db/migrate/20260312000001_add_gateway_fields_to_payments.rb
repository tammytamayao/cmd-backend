# frozen_string_literal: true

class AddGatewayFieldsToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :gateway_provider, :string
    add_column :payments, :gateway_checkout_id, :string
    add_column :payments, :gateway_payment_id, :string

    add_index :payments, :gateway_provider
    add_index :payments, :gateway_checkout_id
    add_index :payments, :gateway_payment_id
  end
end
