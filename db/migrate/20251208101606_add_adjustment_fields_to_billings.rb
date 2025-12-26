class AddAdjustmentFieldsToBillings < ActiveRecord::Migration[7.2]
  def change
    add_column :billings, :adjustment, :decimal
    add_column :billings, :adjustment_notes, :string
  end
end
