class AddPasswordDigestAndRequireChangeToSubscribers < ActiveRecord::Migration[7.2]
  def change
    add_column :subscribers, :password_digest, :string
    add_column :subscribers, :requires_password_change, :boolean
  end
end
