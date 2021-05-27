class User < ApplicationRecord
  has_secure_password

  validate :validate_name, unless: :new_record?
  validates :username, presence: true, uniqueness: { case_sensitive: false, message: "用户名已存在" }, on: :create
  validate :validate_username, on: :create
  validates :email, uniqueness: { message: "邮箱已经注册过了" }
  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP, message: "邮箱格式不对"

  belongs_to :room, optional: true
  has_many :created_rooms, foreign_key: :creator_id, class_name: 'Room', dependent: :nullify
  has_many :messages, dependent: :nullify
  has_many :score_records, dependent: :nullify

  before_create -> { self.name = self.username }, if: -> { name.blank? }
  after_save -> { AvatarGenerationJob.perform_now self }, if: :saved_change_to_name?

  enum status: {
      normal: "normal",
      not_confirmed: "not_confirmed",
      blocked: "blocked"
  }

  def as_json(options={})
    default_options = {only: [:id, :name, :email, :username, :score], methods: [:avatar_url, :thumb_avatar_url]}
    super(default_options.merge(options))
  end

  def avatar_url
    "//#{Constants::App::IMAGE_HOST}/avatars/#{Constants::Avatar::DEFAULT_FILE_NAME % avatar_id}"
  end

  def thumb_avatar_url
    "//#{Constants::App::IMAGE_HOST}/avatars/#{Constants::Avatar::THUMB_FILE_NAME % avatar_id}"
  end

  def join_room(room)
    self.update(room_id: room.id)
  end

  def leave_room
    self.update(room_id: nil)
  end

  def self.login_by(login_name, password)
    return if login_name.blank? || password.blank?

    if login_name.include? "@"
      user = User.find_by(email: login_name)
    else
      user = User.find_by(username: login_name)
    end

    return user if user&.authenticate(password)
  end

  private

  def validate_username
    if not /\A[a-zA-Z0-9_]{2,15}\z/.match?(username)
      errors.add(:username, "只能包含字母、数字和下划线，且长度为2～15")
    elsif /\A_+\z/.match?(username)
      errors.add(:username, "不能全部是下划线")
    end
  end

  def validate_name
    if not /\A[a-zA-Z0-9_\u4e00-\u9fa5]{2,15}\z/.match?(name)
      errors.add(:name, "只能包含中英文、字母、数字和下划线，且长度为2～15")
    elsif /\A_+\z/.match?(name)
      errors.add(:name, "不能全部是下划线")
    end
  end
end
