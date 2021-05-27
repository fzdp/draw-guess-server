ActionRateLimiter
    .add(Constants::RateLimit::SIGN_IN, limit: 10, period: 60, block_time: 5.minutes) {|request|
      request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
    }
    .add(Constants::RateLimit::SIGN_UP, limit: 10, period: 60, block_time: 30.minutes) {|request|
      request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
    }
    .add(Constants::RateLimit::RESET_PASSWORD, limit: 5, period: 60) {|request|
      request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
    }
    .add(Constants::RateLimit::SEND_EMAIL_CODE, limit: 20, period: 5.minutes, block_time: 10.minutes) { |request|
      request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
    }
    .add(Constants::RateLimit::CREATE_ROOM, limit: 10, period: 10.minutes, block_time: 10.minutes) { |user|
      user.id
    }
    .add(Constants::RateLimit::UPDATE_NICK_NAME, limit: 5, period: 1.hours, block_time: 10.minutes) { |user|
      user.id
    }
    .add(Constants::RateLimit::ROOM_CHAT, limit: 30, period: 1.minutes, block_time: 60) { |user, room|
      "#{user.id}_#{room.id}"
    }
    .add(Constants::RateLimit::GENERAL_REQUEST, limit: 100, period: 10, block_time: 5.minutes) { |request|
      request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
    }
