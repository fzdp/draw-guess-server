class RoomChannel < ApplicationCable::Channel
  def subscribed
    return unless current_user
    @room = Room.find params[:room_id]
    stream_for @room

    @room.reload.emit_user_join_room! current_user
    response_json = {
        excluded: current_user.id,
        message: { content: "#{display_user_name(current_user.name)}加入了房间" },
        added: current_user
    }

    if @room.saved_change_to_aasm_state?
      response_json[:data] = @room.as_game_data_json
    end

    broadcast_to @room, response_json
    ActiveSupport::Notifications.instrument "game_lobby.joined", room: @room.as_json
  end

  def unsubscribed
    return unless current_user

    @room.reload.emit_user_leave_room! current_user
    response_json = {
        message: { content: "#{display_user_name(current_user.name)}离开了房间" },
        removed: current_user
    }

    if @room.saved_change_to_aasm_state?
      response_json[:data] = @room.as_game_data_json
    end

    broadcast_to @room, response_json
    ActiveSupport::Notifications.instrument "game_lobby.leaved", room: @room
  end

  def get_room_data
    transmit data: @room.reload.as_game_data_json(full_load: true), message: {
        content: "#{display_user_name(current_user.name)}加入了房间"
    }
  end

  def save_canvas_data(data)
    return unless is_painter?
    GameCanvasProcessingJob.perform_later(@room.current_game_id, @room.painter_id, data["width"], data["height"], data["image"])
  end

  def event_get_words
    return unless is_painter?
    @room.reload.emit_get_words!
    transmit data: { words: get_words }
    broadcast_to @room, data: @room.as_game_data_json
  end

  def event_user_is_ready
    @room.reload.emit_user_is_ready! current_user
    broadcast_to @room, data: @room.as_game_data_json
  end

  def event_user_choose_word(data)
    @room.reload.emit_user_choose_word! data['word'].strip
    broadcast_to @room, data: @room.as_game_data_json, message: { content: "#{display_user_name(@room.painter.name)}正在绘画" }
  end

  def event_user_refresh_words
    return unless is_painter?
    transmit data: { words: get_words }
  end

  def event_user_skip_choosing_word
    return unless is_painter?
    old_painter_name = @room.painter.name
    @room.reload.emit_skip_choose_word!
    broadcast_to @room, data: @room.as_game_data_json, message: {
        content: "#{display_user_name(old_painter_name)}跳过了选词，现在由#{display_user_name(@room.painter.name)}选词"
    }
  end

  def self.event_timeout(room)
    if room.round_start?
      broadcast_to room, data: room.as_game_data_json, message: { content: "现在由#{display_user_name(room.painter.name)}选词" }
    elsif room.round_over?
      broadcast_to room, data: room.as_game_data_json, message: { content: "时间到！本轮游戏结束" }
    end
  end

  def event_user_draw(data)
    if data["operation"]["undo"]
      @room.pop_operation
    else
      operation_data = data["operation"].slice("tool", "attrs")
      if operation_data["tool"] == "clear"
        @room.clear_operations
      else
        @room.add_operation operation_data
      end
    end
    broadcast_to @room, data: { drawingData: data["operation"] }, excluded: @room.painter_id
  end

  def receive(data)
    unless ActionRateLimiter.check?(Constants::RateLimit::ROOM_CHAT, current_user, @room)
      transmit message: { content: "您的访问过于频繁，请稍后重试" }
      return
    end

    return if data["content"].blank?
    chat_message = data["content"].truncate Constants::Room::MAX_CHAT_MESSAGE_SIZE

    if chat_message == @room.answer && @room.reload.drawing?
        broadcast_to @room, message: { content: '*' * chat_message.size, sender: current_user.id }
      unless @room.winner_ids.include?(current_user.id) || is_painter?
        # 注意：必须放在user_guess_right之前，因为user_guess_right可能导致game_over，redis的key_of_time_ended_at就会删除掉
        time_taken = @room.time_taken

        @room.emit_user_guess_right! current_user
        score = GameScoreCalculator.call(@room, time_taken)
        current_painter = @room.painter

        broadcast_to @room, data: @room.as_game_data_json, message: {
            content: "#{display_user_name(current_user.name)}答对了！+#{score}分！画家#{display_user_name(current_painter.name)} +#{Constants::Room::PAINTER_SCORE_ON_GUESS_RIGHT}分！"
        }, scores: { current_user.id => score, @room.painter_id => Constants::Room::PAINTER_SCORE_ON_GUESS_RIGHT }

        GameScoreGenerationJob.perform_later(@room, current_user, current_painter, score: score, time_taken: time_taken)
      end
    else
      broadcast_to @room, message: { content: chat_message, sender: current_user.id }
    end
  end

  private

  def get_words(n=3)
    # WordItem有极小的概率出现重名的情况
    loop do
      word_list = WordItem.order(Arel.sql('RANDOM()')).first(n).pluck(:name).uniq
      return word_list if word_list.size == n
    end
  end

  def is_painter?
    current_user.id == @room.painter_id
  end
end
