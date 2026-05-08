# frozen_string_literal: true

SecureHeaders::Configuration.default do |config|
  config.hsts = "max-age=#{6.months.to_i}; includeSubdomains; preload"
  config.x_frame_options = 'DENY'
  config.x_content_type_options = 'nosniff'
  config.x_xss_protection = '1; mode=block'
  config.x_download_options = 'noopen'
  config.x_permitted_cross_domain_policies = 'none'
  config.referrer_policy = 'strict-origin-when-cross-origin'

  config.csp = {
    report_only: false,
    default_src: ["'none'"],
    script_src: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
    style_src: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
    img_src: ["'self'", 'data:'],
    font_src: ["'self'", 'https://fonts.gstatic.com'],

    connect_src: ["'self'", 'http://localhost:3000', 'http://127.0.0.1:3000', 'ws://localhost:3000'],

    frame_ancestors: ["'none'"],
    form_action: ["'self'"],
    base_uri: ["'self'"]
  }
end
