class AddReceiptMetadataToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :receipt_filename, :string
    add_column :payments, :receipt_size, :bigint
    add_column :payments, :receipt_mime_type, :string
    add_column :payments, :receipt_uploaded_at, :datetime

    add_index :payments, :receipt_uploaded_at
  end
end
