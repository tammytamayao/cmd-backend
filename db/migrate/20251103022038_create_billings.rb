class CreateBillings < ActiveRecord::Migration[7.2]
  def change
    create_table :billings do |t|
      t.date :start_date
      t.date :end_date
      t.decimal :amount
      t.date :due_date
      t.string :status
      t.references :subscriber, null: false, foreign_key: true

      t.timestamps
    end
  end
end
