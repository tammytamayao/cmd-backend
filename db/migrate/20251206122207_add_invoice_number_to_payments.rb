class AddInvoiceNumberToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :invoice_number, :string
  end
end
