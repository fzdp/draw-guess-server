class ApplicationController < ActionController::API
  before_action :validate_token
  before_action :validate_user
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: '请求的资源不存在' }, status: :not_found
  end

  rescue_from ActionRateLimiter::TooManyRequestsError do |exec|
    render json: { error: exec.message }, status: :too_many_requests
  end

  def validate_token
    token = get_token
    if token
      begin
        payload = JsonWebToken.decode token
        @current_user ||= User.find(payload.fetch(:user_id, nil))
      rescue JWT::DecodeError
        render json: { error: "invalid token"}, status: :unauthorized
      rescue JWT::ExpiredSignature
        render json: { error: "token expired" }, status: :unauthorized
      rescue ActiveRecord::RecordNotFound
        render json: { error: "user not found" }, status: :unauthorized
      rescue
        render json: { error: "invalid token" }, status: :unauthorized
      end
    else
      render json: { error: "token missing" }, status: :unauthorized
    end
  end

  def current_user
    @current_user ||=
        begin
          payload = JsonWebToken.decode get_token
          User.find(payload.fetch(:user_id, nil))
        rescue
          nil
        end
  end

  def validate_user
    if current_user && !current_user.normal?
      render json: { error: "forbidden" }, status: :forbidden
    end
  end

  private

  def get_token
    # header: { 'Authorization': 'Bearer <token>' }
    request.headers['Authorization']&.split(' ')&.last
  end
end
