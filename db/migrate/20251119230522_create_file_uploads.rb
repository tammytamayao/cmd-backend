class CreateFileUploads < ActiveRecord::Migration[7.2]
  def change
    create_table :file_uploads do |t|
      t.references :subscriber, null: false, foreign_key: true
      t.string :s3_key, null: false, index: true
      t.string :original_filename, null: false
      t.bigint :file_size
      t.string :mime_type
      t.string :etag

      t.timestamps
    end

    add_index :file_uploads, [ :subscriber_id, :created_at ]
  end
end
