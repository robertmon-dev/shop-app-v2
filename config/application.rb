# config/application.rb
require_relative 'boot'

require 'rails/all'
require 'active_record/railtie'
require 'active_model/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ShopOnRails
  class Application < Rails::Application
    config.active_record.observers = :order_observer, :user_observer, :product_observer, :cart_observer,
                                     :verification_code_observer, :activation_code_observer,
                                     :payment_observer, :invoice_observer, :refund_observer

    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true

    config.after_initialize do
      Rails.application.routes.default_url_options[:host] = 'localhost'
      Rails.application.routes.default_url_options[:port] = 3000
    end
  end
end
