# config/initializers/openssl_crl_fix.rb
require "openssl"

# Ignore ONLY the "unable to get certificate CRL" error.
# All other SSL errors still fail as normal.
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:verify_callback] =
  proc do |preverify_ok, store_ctx|
    if !preverify_ok && store_ctx.error == OpenSSL::X509::V_ERR_UNABLE_TO_GET_CRL
      # You can log this if you want:
      # Rails.logger.warn("Ignoring CRL error for #{store_ctx.current_cert.subject}")
      true
    else
      preverify_ok
    end
  end
