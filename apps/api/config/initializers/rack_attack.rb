# frozen_string_literal: true

class Rack::Attack
  self.enabled = false if Rails.env.test?

  cache.store = ActiveSupport::Cache::MemoryStore.new

  # Stripe and n8n call from a few shared IPs and are authenticated by signature/secret, so the
  # per-IP limits below would only make us drop legitimate events (Stripe retries, then gives up).
  WEBHOOK_PATHS = %w[/api/v1/stripe_payments_webhook/handle /api/v1/n8n_webhook/handle].freeze
  safelist('webhooks') { |req| req.post? && WEBHOOK_PATHS.include?(req.path) }

  throttle('req/ip', limit: 60, period: 60) do |req|
    req.ip
  end

  throttle('logins/email+ip', limit: 6, period: 60) do |req|
    [req.params['mail'].to_s.downcase, req.ip] if req.path == '/api/v1/auth/login' && req.post?
  end

  throttle('password_reset/ip', limit: 3, period: 1.hour) do |req|
    req.ip if req.path == '/api/v1/auth/password/reset' && req.post?
  end

  throttle('users/create', limit: 4, period: 1.hour) do |req|
    req.ip if req.path == '/api/v1/users' && req.post?
  end

  self.throttled_responder = lambda do |_env|
    [429, { 'Content-Type' => 'application/json' }, [{ error: 'Throttle limit exceeded' }.to_json]]
  end
end

ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _request_id, payload|
  req = payload[:request]
  Rails.logger.warn "[rack-attack] Throttled request from IP: #{req.ip} to path: #{req.path}"
end
