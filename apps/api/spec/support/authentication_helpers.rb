module AuthenticationHelpers
  def generate_jwt_for(user)
    payload = { user_id: user.id }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
end
