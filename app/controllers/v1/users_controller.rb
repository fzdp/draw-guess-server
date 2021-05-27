class V1::UsersController < ApplicationController
  skip_before_action :validate_token, only: [:create, :login, :send_sign_up_email, :send_reset_password_email, :reset_password]
  before_action :check_email, only: [:send_sign_up_email, :send_reset_password_email]

  def create
    ActionRateLimiter.check!(Constants::RateLimit::SIGN_UP, request)
    email_code = params[:email_code]
    if email_code.blank?
      render json: { error: { emailCode: ["请填写验证码"] } } and return
    end

    cache_key = email_code_key(params[:email], "sign_up")
    cached_code = $redis.with { |c| c.get(cache_key) }
    if cached_code.blank?
      render json: { error: { emailCode: ["请重新获取验证码"] } } and return
    elsif cached_code != email_code
      render json: { error: { emailCode: ["验证码错误"] } } and return
    end

    user = User.new user_params
    if user.save
      user.normal!
      $redis.with { |c| c.del cache_key }
      token = JsonWebToken.encode({ user_id: user.id })
      render json: { data: { token: token, user: user } }
    else
      render json: { error: user.errors }
    end
  end

  def login
    user = User.login_by(params[:login], user_params[:password])
    if user
      token = JsonWebToken.encode({user_id: user.id})
      render json: { data: { token: token, user: user } }
    else
      ActionRateLimiter.check!(Constants::RateLimit::SIGN_IN, request)
      render json: { error: "登录名或者密码有误" }
    end
  end

  def update_name
    ActionRateLimiter.check!(Constants::RateLimit::UPDATE_NICK_NAME, current_user)

    name = user_params[:name]
    if current_user.update(name: name)
      render json: { data: current_user.as_json(only: [:name]) }
    else
      render json: { error: '更新失败' }
    end
  end

  def get_profile
    render json: { data: current_user }
  end

  def send_sign_up_email
    validation_result = User.validate_attributes email: @email
    if validation_result[0]
      send_sign_up_email_code(@email)
      render json: { data: "发送成功" }
    else
      render json: { error: validation_result[1] }
    end
  end

  def send_reset_password_email
    user = User.find_by(email: @email)
    if user.blank?
      render json: { error: "此邮箱没有关联账号，请填写您的登录邮箱" } and return
    end

    if user.blocked?
      render json: { error: "此邮箱关联的账号已经被冻结" } and return
    end

    send_reset_password_email_code(@email, user)
    render json: { data: "发送成功" }
  end

  def reset_password
    ActionRateLimiter.check!(Constants::RateLimit::RESET_PASSWORD, request)
    user = User.find_by(email: user_params[:email])
    if user.blank?
      render json: {error: "邮箱无效"} and return
    end

    cached_key = email_code_key(user_params[:email], "reset_password")
    real_token = $redis.with { |c| c.get(cached_key) }
    if real_token.blank?
      render json: { error: "验证码已过期，请重新获取" }
    else
      confirmation_token = params[:token]
      if confirmation_token.blank?
        render json: { error: "提交的验证码不能为空值" }
      elsif confirmation_token == real_token
        if user.update(user_params.slice(:password, :password_confirmation))
          $redis.with { |c| c.del cached_key }
          render json: { data: "密码重置成功" }
        else
          render json: { error: user.errors.full_messages }
        end
      else
        render json: { error: "验证码错误" }
      end
    end
  end

  private

  def user_params
    params.permit(:email, :password, :password_confirmation, :name, :username)
  end

  def send_sign_up_email_code(email)
    code = generate_secure_token
    ex_minutes = 30
    $redis.with { |c| c.set(email_code_key(email, "sign_up"), code, ex: ex_minutes.minutes.to_i) }
    AccountMailer.with(email: email, code: code, minutes: ex_minutes).email_confirmation.deliver_later
  end

  def send_reset_password_email_code(email, user)
    code = generate_secure_token
    ex_minutes = 10
    $redis.with { |c| c.set(email_code_key(email, "reset_password"), code, ex: ex_minutes.minutes.to_i) }
    AccountMailer.with(email: email, code: code, minutes: ex_minutes, user: user).password_reset.deliver_later
  end

  def generate_secure_token
    (SecureRandom.random_number(9e5) + 1e5).to_i.to_s
  end

  def email_code_key(email, scene)
    raise "invalid email code scene" unless Constants::Email::EMAIL_CODE_SCENES.include?(scene)
    "code:#{scene}:#{email}"
  end

  def check_email
    @email = params[:email]
    if @email.blank?
      render json: { error: "请填写邮箱" }, status: :bad_request
    else
      ActionRateLimiter.check!(Constants::RateLimit::SEND_EMAIL_CODE, request)
    end
  end
end
