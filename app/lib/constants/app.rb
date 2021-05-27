module Constants
  module App
    IMAGE_HOST = Rails.env.production? ? "www.udig.online" : "192.168.1.3:3000"
  end
end