class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.dig(:smtp, :sender)
  layout 'mailer'
end
