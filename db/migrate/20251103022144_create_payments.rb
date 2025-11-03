class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.date :payment_date
      t.decimal :amount
      t.string :method
      t.string :status
      t.string :attachment
      t.string :reference_number
      t.references :billing, null: false, foreign_key: true

      t.timestamps
    end
  end
end
