# frozen_string_literal: true

module IntegrationHelpers
  def bearer(user)
    "Bearer #{Auth::Bearer.encode({ user_id: user.id }).data[:token]}"
  end
end

RSpec.configure do |config|
  config.include IntegrationHelpers, file_path: %r{spec/integration}
end
