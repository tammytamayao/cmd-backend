class CreateAdminUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :admin_users do |t|
      t.string :email,           null: false
      t.string :role,            null: false, default: "billing_officer"
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :admin_users, :email, unique: true
    add_index :admin_users, :role
  end
end
