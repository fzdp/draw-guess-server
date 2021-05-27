class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base

  def self.encode(payload, expire = 1.week.after)
    payload[:exp] = expire.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  # returns payload, e.g. { user_id: 2 }
  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY).first
    HashWithIndifferentAccess.new decoded
  end
end