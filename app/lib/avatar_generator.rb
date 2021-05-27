require 'mini_magick'

class AvatarGenerator
  SAVE_DIR = Rails.env.development? ? Rails.public_path.join("avatars") : Rails.application.credentials.avatars_dir

  def initialize(user)
    @user = user
  end

  def call
    avatar_id = SecureRandom.hex(10)
    while User.exists?(avatar_id: avatar_id)
      avatar_id = SecureRandom.hex(10)
    end

    letters = @user.name.remove("_").first(2)
    raise "letters required" if letters.blank?

    MiniMagick::Tool::Convert.new do |image|
      image.size default_size
      image.gravity 'center'
      image.xc Constants::Avatar::BACKGROUND_COLORS.sample
      image.pointsize /\p{Han}+/.match(letters) ? Constants::Avatar::FONT_SIZE : Constants::Avatar::LARGE_FONT_SIZE
      image.font Constants::Avatar::FONT
      image.fill Constants::Avatar::TEXT_COLORS.sample
      image.draw "text 0,0 '#{letters}'"
      image << image_save_path(avatar_id)
    end

    MiniMagick::Image.open(image_save_path(avatar_id))
        .resize(thumb_size)
        .write(thumb_save_path(avatar_id))

    old_avatar_id = @user.avatar_id
    @user.update_column(:avatar_id, avatar_id)

    if File.exists?(image_save_path(old_avatar_id))
      File.delete image_save_path(old_avatar_id)
    end

    if File.exists?(thumb_save_path(old_avatar_id))
      File.delete thumb_save_path(old_avatar_id)
    end

    avatar_id
  end

  private

  def image_save_path(avatar_id)
    "#{SAVE_DIR}/#{Constants::Avatar::DEFAULT_FILE_NAME % avatar_id}"
  end

  def thumb_save_path(avatar_id)
    "#{SAVE_DIR}/#{Constants::Avatar::THUMB_FILE_NAME % avatar_id}"
  end

  def thumb_size
    "#{Constants::Avatar::THUMB_WIDTH}x#{Constants::Avatar::THUMB_WIDTH}"
  end

  def default_size
    "#{Constants::Avatar::DEFAULT_WIDTH}x#{Constants::Avatar::DEFAULT_WIDTH}"
  end
end