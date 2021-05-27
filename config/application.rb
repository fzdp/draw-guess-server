require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative '../app/lib/action_rate_limiter.rb'

module DrawAndGuessServer
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.time_zone = 'Beijing'
    config.api_only = true
    config.i18n.default_locale = :'zh-CN'

    config.action_mailer.smtp_settings = {
        address: Rails.application.credentials.dig(:smtp, :address),
        port: Rails.application.credentials.dig(:smtp, :port),
        user_name: Rails.application.credentials.dig(:smtp, :user_name),
        password: Rails.application.credentials.dig(:smtp, :password),
        authentication: "plain",
        tls: true
    }

    config.middleware.use ActionRateLimiter
  end
end
