# frozen_string_literal: true

class Rack::Attack
  self.enabled = false if Rails.env.test?

  cache.store = ActiveSupport::Cache::MemoryStore.new

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
