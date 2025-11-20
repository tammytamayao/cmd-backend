# frozen_string_literal: true

class Api::V1::S3Controller < ApplicationController
  before_action :authenticate_request!, except: [ :health ]

  # GET /api/v1/s3/health
  # Check S3 connectivity
  def health
    result = S3Helper.health_check
    render json: result, status: :ok
  end

  # GET /api/v1/s3/debug
  # Debug endpoint - list all files without auth (for testing only)
  def debug
    files_result = S3Helper.list_all_files(max_keys: 1000)

    if files_result[:success]
      render json: {
        message: "Debug - All S3 files",
        data: files_result[:files],
        count: files_result[:count],
        is_truncated: files_result[:is_truncated]
      }, status: :ok
    else
      render json: { error: files_result[:error] }, status: :internal_server_error
    end
  end

  # GET /api/v1/s3/files/:id
  # Get details about a specific file
  def show
    file_upload = FileUpload.find_by(id: params[:id])

    if file_upload.nil?
      return render json: { error: "File not found" }, status: :not_found
    end

    file_info = S3Helper.get_file(file_upload.s3_key)

    if file_info[:success]
      render json: {
        data: {
          id: file_upload.id,
          s3_key: file_upload.s3_key,
          filename: file_upload.original_filename,
          size: file_upload.file_size,
          mime_type: file_upload.mime_type,
          uploaded_at: file_upload.created_at,
          last_modified: file_info[:last_modified],
          etag: file_info[:etag]
        }
      }, status: :ok
    else
      render json: { error: file_info[:error] }, status: :internal_server_error
    end
  end

  # GET /api/v1/s3/files
  # List uploaded files with optional filtering
  def index
    page = (params[:page] || 1).to_i
    per_page = [ (params[:per_page] || 20).to_i, 100 ].min
    offset = (page - 1) * per_page
    subscriber_id = params[:subscriber_id]

    # Determine which subscriber(s) to list files for
    if subscriber_id.present?
      files_result = S3Helper.list_by_subscriber(subscriber_id.to_i, max_keys: per_page)
    else
      files_result = S3Helper.list_all_files(max_keys: per_page)
    end

    if files_result[:success]
      render json: {
        data: files_result[:files],
        pagination: {
          page: page,
          per_page: per_page,
          total_count: files_result[:count],
          is_truncated: files_result[:is_truncated],
          next_continuation_token: files_result[:next_continuation_token]
        }
      }, status: :ok
    else
      render json: { error: files_result[:error] }, status: :internal_server_error
    end
  end

  # POST /api/v1/s3/files
  # Upload a file to S3
  def create
    file = params[:file]
    subscriber_id = params[:subscriber_id]

    # Validate presence of required fields
    if file.nil?
      return render json: { error: "File is required" }, status: :bad_request
    end

    if subscriber_id.nil?
      return render json: { error: "Subscriber ID is required" }, status: :bad_request
    end

    # Use current authenticated subscriber if not provided or verify authorization
    current_subscriber_id = @current_subscriber&.id
    subscriber_id = subscriber_id.to_i

    # Optional: Enforce that users can only upload to their own folder
    # Uncomment the following lines to restrict uploads to authenticated user's folder
    # unless current_subscriber_id == subscriber_id
    #   return render json: { error: "You can only upload files to your own folder" },
    #                  status: :forbidden
    # end

    upload_result = S3Helper.upload(file, subscriber_id)

    if upload_result[:success]
      # Save file metadata to database
      begin
        file_upload = FileUpload.create_from_upload(
          subscriber_id,
          upload_result[:s3_key],
          upload_result[:filename],
          upload_result[:size],
          upload_result[:mime_type],
          nil # etag will be set after upload
        )

        render json: {
          data: {
            id: file_upload.id,
            s3_key: file_upload.s3_key,
            filename: file_upload.original_filename,
            size: file_upload.file_size,
            mime_type: file_upload.mime_type,
            uploaded_at: file_upload.created_at
          }
        }, status: :created
      rescue StandardError => e
        # Rollback S3 upload if database save fails
        S3Helper.delete(upload_result[:s3_key])
        render json: { error: "Failed to save file metadata: #{e.message}" },
               status: :internal_server_error
      end
    else
      render json: { error: upload_result[:error] }, status: :bad_request
    end
  end

  # GET /api/v1/s3/files/:id/download
  # Download file blob
  def download
    file_upload = FileUpload.find_by(id: params[:id])

    if file_upload.nil?
      return render json: { error: "File not found" }, status: :not_found
    end

    download_file(file_upload)
  end

  # GET /api/v1/s3/debug/files/:id/download
  # Debug endpoint - download file blob without auth
  def debug_download
    file_upload = FileUpload.find_by(id: params[:id])

    if file_upload.nil?
      return render json: { error: "File not found" }, status: :not_found
    end

    download_file(file_upload)
  end

  # DELETE /api/v1/s3/files/:id
  # Delete a file from S3
  def destroy
    file_upload = FileUpload.find_by(id: params[:id])

    if file_upload.nil?
      return render json: { error: "File not found" }, status: :not_found
    end

    deletion_result = S3Helper.delete(file_upload.s3_key)

    if deletion_result[:success]
      file_upload.destroy
      render json: { message: "File deleted successfully" }, status: :ok
    else
      render json: { error: deletion_result[:error] }, status: :internal_server_error
    end
  end

  private

  def download_file(file_upload)
    begin
      client = Aws::S3::Client.new(
        access_key_id: ENV["AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
        region: ENV["AWS_S3_REGION"] || "us-east-1"
      )

      response = client.get_object(
        bucket: ENV["AWS_S3_BUCKET"],
        key: file_upload.s3_key
      )

      send_data(
        response.body.read,
        filename: file_upload.original_filename,
        type: file_upload.mime_type || "application/octet-stream",
        disposition: "attachment"
      )
    rescue StandardError => e
      render json: { error: "Failed to download file: #{e.message}" },
             status: :internal_server_error
    end
  end
end
