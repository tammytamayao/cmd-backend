# frozen_string_literal: true

# AWS Credentials Configuration
# This initializer sets AWS credentials based on the ENVIRONMENT_MODE variable
# ENVIRONMENT_MODE can be: "local", "staging"/"stg", or "production"/"prod"

environment_mode = ENV.fetch('ENVIRONMENT_MODE', 'local').downcase

case environment_mode
when 'staging', 'stg'
  # Use staging credentials
  ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_ACCESS_KEY_ID_STAGING'] if ENV['AWS_ACCESS_KEY_ID_STAGING'].present?
  ENV['AWS_SECRET_ACCESS_KEY'] = ENV['AWS_SECRET_ACCESS_KEY_STAGING'] if ENV['AWS_SECRET_ACCESS_KEY_STAGING'].present?
  ENV['AWS_S3_BUCKET'] = ENV['AWS_S3_BUCKET_STAGING'] if ENV['AWS_S3_BUCKET_STAGING'].present?
  ENV['AWS_S3_REGION'] = ENV['AWS_S3_REGION_STAGING'] if ENV['AWS_S3_REGION_STAGING'].present?

  Rails.logger.info "🔧 AWS Credentials set to STAGING environment"

when 'production', 'prod'
  # Use production credentials
  ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_ACCESS_KEY_ID_PRODUCTION'] if ENV['AWS_ACCESS_KEY_ID_PRODUCTION'].present?
  ENV['AWS_SECRET_ACCESS_KEY'] = ENV['AWS_SECRET_ACCESS_KEY_PRODUCTION'] if ENV['AWS_SECRET_ACCESS_KEY_PRODUCTION'].present?
  ENV['AWS_S3_BUCKET'] = ENV['AWS_S3_BUCKET_PRODUCTION'] if ENV['AWS_S3_BUCKET_PRODUCTION'].present?
  ENV['AWS_S3_REGION'] = ENV['AWS_S3_REGION_PRODUCTION'] if ENV['AWS_S3_REGION_PRODUCTION'].present?

  Rails.logger.info "🔧 AWS Credentials set to PRODUCTION environment"

when 'local'
  # Use local/default credentials (already in ENV['AWS_ACCESS_KEY_ID'], etc.)
  Rails.logger.info "🔧 AWS Credentials set to LOCAL environment"

else
  Rails.logger.warn "⚠️  Unknown ENVIRONMENT_MODE: #{environment_mode}. Using LOCAL credentials as fallback."
end

# Log which AWS region is being used (without exposing credentials)
Rails.logger.info "🌍 AWS Region: #{ENV['AWS_S3_REGION']}" if ENV['AWS_S3_REGION'].present?
Rails.logger.info "🪣 AWS S3 Bucket: #{ENV['AWS_S3_BUCKET']}" if ENV['AWS_S3_BUCKET'].present?
