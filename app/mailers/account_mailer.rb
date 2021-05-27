class AccountMailer < ApplicationMailer
  def email_confirmation
    @welcome = params[:user] ? "#{params[:user].name} 您好" : "您好"
    @code = params[:code]
    @minutes = params[:minutes]
    mail(to: params[:email], subject: '您的邮箱需要验证')
  end

  def password_reset
    @welcome = params[:user] ? "#{params[:user].name} 您好" : "您好"
    @code = params[:code]
    @minutes = params[:minutes]
    mail(to: params[:email], subject: "您的登录密码即将重置")
  end
end