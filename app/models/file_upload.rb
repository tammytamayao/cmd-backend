# frozen_string_literal: true

class FileUpload < ApplicationRecord
  belongs_to :subscriber

  validates :subscriber_id, presence: true
  validates :s3_key, presence: true, uniqueness: true
  validates :original_filename, presence: true
  validates :file_size, numericality: { greater_than: 0, allow_nil: true }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_subscriber, ->(subscriber_id) { where(subscriber_id: subscriber_id) }

  def self.create_from_upload(subscriber_id, s3_key, filename, size, mime_type, etag)
    create!(
      subscriber_id: subscriber_id,
      s3_key: s3_key,
      original_filename: filename,
      file_size: size,
      mime_type: mime_type,
      etag: etag
    )
  end
end
