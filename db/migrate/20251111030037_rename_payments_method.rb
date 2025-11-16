class RenamePaymentsMethod < ActiveRecord::Migration[7.2]
  def change
    rename_column :payments, :method, :payment_method
    add_index :payments, :payment_method
  end
end
