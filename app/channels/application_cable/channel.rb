module ApplicationCable
  class Channel < ActionCable::Channel::Base
    after_subscribe :ensure_user_exists

    def ensure_user_exists
      if [RoomChannel].include?(self.class) && current_user.blank?
        reject_subscription
      end
    end

    def display_user_name(name)
      self.class.display_user_name name
    end

    def self.display_user_name(name)
      "【#{name}】"
    end
  end
end
