# frozen_string_literal: true

module S3Helper
  class S3Error < StandardError; end

  class << self
    # Check if S3 is connected and accessible
    def health_check
      begin
        client = aws_s3_client
        client.head_bucket(bucket: bucket_name)
        { status: "connected", timestamp: Time.current, message: "S3 connection successful" }
      rescue StandardError => e
        { status: "disconnected", timestamp: Time.current, message: e.message }
      end
    end

    # Upload a file to S3
    # @param file [File] The file to upload
    # @param subscriber_id [Integer] The subscriber ID for folder organization
    # @param metadata [Hash] Optional metadata
    # @return [Hash] Upload result with S3 key and file metadata
    def upload(file, subscriber_id, metadata = {})
      raise S3Error, "File is required" if file.nil?
      raise S3Error, "Subscriber ID is required" if subscriber_id.nil?

      key = generate_key(subscriber_id, file.original_filename)

      begin
        client = aws_s3_client
        client.put_object(
          bucket: bucket_name,
          key: key,
          body: file.read,
          content_type: file.content_type || "application/octet-stream"
        )

        {
          success: true,
          s3_key: key,
          filename: file.original_filename,
          size: file.size,
          mime_type: file.content_type,
          uploaded_at: Time.current
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    # Delete a file from S3
    # @param s3_key [String] The S3 key/path of the file
    # @return [Hash] Deletion result
    def delete(s3_key)
      raise S3Error, "S3 key is required" if s3_key.nil? || s3_key.empty?

      begin
        client = aws_s3_client
        client.delete_object(bucket: bucket_name, key: s3_key)
        { success: true, message: "File deleted successfully" }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    # Retrieve file metadata from S3
    # @param s3_key [String] The S3 key/path of the file
    # @return [Hash] File metadata
    def get_file(s3_key)
      raise S3Error, "S3 key is required" if s3_key.nil? || s3_key.empty?

      begin
        client = aws_s3_client
        response = client.head_object(bucket: bucket_name, key: s3_key)

        {
          success: true,
          s3_key: s3_key,
          filename: extract_filename(s3_key),
          size: response.content_length,
          mime_type: response.content_type,
          last_modified: response.last_modified,
          etag: response.etag
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    # List all files for a specific subscriber
    # @param subscriber_id [Integer] The subscriber ID to list files for
    # @param options [Hash] Optional parameters (max_keys, continuation_token, etc.)
    # @return [Array<Hash>] Array of file metadata objects
    def list_by_subscriber(subscriber_id, options = {})
      raise S3Error, "Subscriber ID is required" if subscriber_id.nil?

      prefix = "uploads/#{subscriber_id}/"
      max_keys = options[:max_keys] || 100
      continuation_token = options[:continuation_token]

      begin
        client = aws_s3_client

        list_params = {
          bucket: bucket_name,
          prefix: prefix,
          max_keys: max_keys
        }
        list_params[:continuation_token] = continuation_token if continuation_token

        response = client.list_objects_v2(list_params)

        files = (response.contents || []).map do |object|
          {
            s3_key: object.key,
            filename: extract_filename(object.key),
            size: object.size,
            uploaded_at: object.last_modified,
            etag: object.etag
          }
        end

        {
          success: true,
          files: files,
          is_truncated: response.is_truncated,
          next_continuation_token: response.next_continuation_token,
          count: files.length
        }
      rescue StandardError => e
        { success: false, error: e.message, files: [] }
      end
    end

    # List all files across all subscribers
    # @param options [Hash] Optional parameters (max_keys, continuation_token, etc.)
    # @return [Array<Hash>] Array of file metadata objects
    def list_all_files(options = {})
      prefix = "uploads/"
      max_keys = options[:max_keys] || 100
      continuation_token = options[:continuation_token]

      begin
        client = aws_s3_client

        list_params = {
          bucket: bucket_name,
          prefix: prefix,
          max_keys: max_keys
        }
        list_params[:continuation_token] = continuation_token if continuation_token

        response = client.list_objects_v2(list_params)

        files = (response.contents || []).map do |object|
          {
            s3_key: object.key,
            filename: extract_filename(object.key),
            subscriber_id: extract_subscriber_id(object.key),
            size: object.size,
            uploaded_at: object.last_modified,
            etag: object.etag
          }
        end

        {
          success: true,
          files: files,
          is_truncated: response.is_truncated,
          next_continuation_token: response.next_continuation_token,
          count: files.length
        }
      rescue StandardError => e
        { success: false, error: e.message, files: [] }
      end
    end

    private

    # Get AWS S3 client
    def aws_s3_client
      @client ||= Aws::S3::Client.new(
        access_key_id: ENV["AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
        region: ENV["AWS_S3_REGION"] || "us-east-1"
      )
    end

    # Get S3 bucket name
    def bucket_name
      @bucket_name ||= ENV["AWS_S3_BUCKET"] || raise(S3Error, "AWS_S3_BUCKET environment variable is not set")
    end

    # Generate S3 key for file storage
    def generate_key(subscriber_id, filename)
      sanitized_filename = File.basename(filename).gsub(/[^\w.-]/, "_")
      "uploads/#{subscriber_id}/#{Time.current.to_i}_#{sanitized_filename}"
    end

    # Extract filename from S3 key
    def extract_filename(s3_key)
      s3_key.split("/").last
    end

    # Extract subscriber ID from S3 key
    def extract_subscriber_id(s3_key)
      parts = s3_key.split("/")
      parts[1] if parts.length >= 3 && parts[0] == "uploads"
    end
  end
end
