class CreateSubscribers < ActiveRecord::Migration[7.2]
  def change
    create_table :subscribers do |t|
      t.string :collector
      t.string :zone
      t.date :date_installed
      t.string :last_name
      t.string :first_name
      t.string :phone_number
      t.string :alternative_phone
      t.string :serial_number
      t.boolean :tvconnect
      t.string :package
      t.string :plan
      t.integer :brate
      t.string :mc_address
      t.string :stb
      t.string :cas
      t.integer :package_speed

      t.timestamps
    end
  end
end
