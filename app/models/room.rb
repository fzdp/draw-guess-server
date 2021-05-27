class Room < ApplicationRecord
  validates :name, presence: true, length: { in: 2..20 }, uniqueness: true
  validates_format_of :password, with: /\A[a-zA-Z0-9]{4,12}\z/, unless: :is_public?

  has_many :messages, dependent: :destroy
  has_many :games, dependent: :nullify
  has_many :score_records

  belongs_to :creator, foreign_key: :creator_id, class_name: 'User'

  scope :is_public, -> { where(is_public: true) }
  scope :is_private, -> { where(is_public: false) }
  scope :is_private_by, -> (user) { user.present? ? where(creator_id: user.id, is_public: false) : none }
  scope :accessed_by, -> (user) { is_public.or(is_private_by(user)) }

  after_destroy {|room| room.delete_all_keys }

  # DKM: server client data key mapping
  DKM = {
      game_state: "gameState",
      joined_users: "joinedUsers",
      room: "room",
      ready_user_ids: "readyUserIds",
      winner_ids: "winnerIds",
      words: "words",
      painter_id: "painterId",
      answer_hint: "answerHint",
      answer: "answer",
      messages: "messages",
      operations: "canvasOperations",
      countdown: "countdown"
  }

  def as_game_data_json(full_load: false, with_joined_users: false)
    if full_load
      json_data = {
          game_state: self.aasm_state,
          room: self,
          joined_users: self.joined_users,
          ready_user_ids: self.ready_user_ids,
          winner_ids: self.winner_ids,
          painter_id: self.painter_id,
          answer_hint: self.answer_hint,
          answer: self.answer,
          countdown: self.get_countdown,
          operations: self.get_operations
      }
      json_data.delete(:answer) if self.drawing?
    else
      case self.aasm_state
      when "no_body", "wait_for_joining"
        json_data = {
            game_state: self.aasm_state,
        }
      when "wait_for_ready"
        json_data = {
            game_state: self.aasm_state,
            ready_user_ids: self.ready_user_ids
        }
      when "round_start"
        json_data = {
            game_state: self.aasm_state,
            painter_id: self.painter_id,
        }
      when "choosing_word"
        json_data = {
            game_state: self.aasm_state,
            painter_id: self.painter_id,
            countdown: self.get_countdown
        }
      when "drawing"
        json_data = {
            game_state: self.aasm_state,
            painter_id: self.painter_id,
            answer_hint: self.answer_hint,
            countdown: self.get_countdown,
            winner_ids: self.winner_ids
        }
      when "round_over"
        json_data = {
            game_state: self.aasm_state,
            winner_ids: self.winner_ids,
            answer: self.answer,
            countdown: self.get_countdown
        }
      else
        return {}
      end
    end

    json_data[:joined_users] = self.joined_users if with_joined_users
    json_data.transform_keys! {|key| DKM[key] || key}
  end

  def as_json(options={})
    default_options = {
        only: [:id, :name, :is_public, :password],
        methods: [:joined_count],
        include: { creator: { only: [:id, :name, :email, :room_id] } }
    }

    super(default_options.merge(options))
  end

  include AASM

  aasm whiny_transitions: false do
    state :no_body, initial: true, after_enter: :enter_no_body
    state :wait_for_joining
    state :wait_for_ready, after_enter: :enter_wait_for_ready
    state :round_start, after_enter: :enter_round_start
    state :choosing_word
    state :drawing, after_enter: :enter_drawing
    state :round_over, after_enter: :enter_round_over

    after_all_transitions :handle_state_change

    event :emit_user_join_room, before: :add_user do
      transitions from: :wait_for_joining, to: :wait_for_ready
      transitions from: :no_body, to: :wait_for_joining
    end

    event :emit_user_is_ready, before: :add_ready_user do
      transitions from: :wait_for_ready, to: :round_start, if: :are_all_users_ready?
    end

    event :emit_get_words do
      transitions from: :round_start, to: :choosing_word
    end

    event :emit_user_choose_word, before: :set_answer_and_hint do
      transitions from: :choosing_word, to: :drawing
    end

    event :emit_user_guess_right, before: :add_winner do
      transitions from: :drawing, to: :round_over, if: :are_all_users_guess_right?
    end

    event :emit_user_leave_room, before: :remove_user do
      transitions to: :wait_for_joining, if: :is_only_one_user?
      transitions to: :no_body, if: :is_no_user?
      transitions from: :choosing_word, to: :round_start, if: :is_painter?
      transitions from: :drawing, to: :round_over, if: :is_painter?
      transitions from: :wait_for_ready, to: :round_start, if: :are_all_users_ready?
    end

    event :emit_timeout, after: :broadcast_timeout do
      transitions from: :drawing, to: :round_over
      transitions from: [:choosing_word, :round_over], to: :round_start
    end

    event :emit_skip_choose_word do
      transitions from: :choosing_word, to: :round_start
    end
  end

  def handle_state_change
    clear_operations unless aasm.to_state == :round_over

    if [:no_body, :wait_for_joining, :wait_for_ready, :round_start].include?(aasm.to_state)
      stop_timer
    elsif aasm.to_state == :choosing_word
      start_timer Constants::Room::COUNTDOWN_CHOOSE_WORD
    elsif aasm.to_state == :drawing
      start_timer Constants::Room::COUNTDOWN_DRAW
    elsif aasm.to_state == :round_over
      start_timer Constants::Room::COUNTDOWN_ROUND_OVER
    end
  end

  def enter_no_body
    delete_all_keys
  end

  def enter_wait_for_ready
    $redis.with { |c| c.del key_of_ready_user_ids }
  end

  def enter_round_start
    set_painter
  end

  def enter_drawing
    $redis.with { |c| c.del key_of_winner_ids }
    game_id = self.games.create(
        user_ids: self.joined_user_ids, painter_id: self.painter_id,
        answer: self.answer, answer_hint: self.answer_hint
    ).id
    $redis.with { |c| c.set(key_of_game_id, game_id) }
  end

  def enter_round_over
    self.current_game.update(
        user_ids: self.joined_user_ids, operations: Game.get_operations(self.id), winner_ids: self.winner_ids
    )
    clear_operations
  end

  def delete_all_keys
    $redis.with do |c|
      c.keys("room_#{id}:*").each { |key| c.del key }
    end
  end

  def set_answer_and_hint(answer_text)
    tag_text = WordItem.find_by(name: answer_text).word_tag.name
    hint_text = "#{answer_text.size}个字， #{tag_text}"

    $redis.with do |c|
      c.set(key_of_answer, answer_text)
      c.set(key_of_answer_hint, hint_text)
    end
  end

  def set_painter
    total_user_ids = $redis.with {|c| c.lrange(key_of_joined_user_ids, 0, -1).map(&:to_i)}
    current_painter_id = $redis.with {|c| c.get(key_of_drawing_user_id).to_i}
    current_painter_index = total_user_ids.index current_painter_id

    if current_painter_index
      painter_index = (current_painter_index + 1) % total_user_ids.size
    else
      painter_index = 0
    end

    painter_id = total_user_ids[painter_index]
    $redis.with { |c| c.set(key_of_drawing_user_id, painter_id) }
  end

  def add_user(user)
    return if joined_user_ids.include? user.id
    $redis.with {|c| c.rpush(key_of_joined_user_ids, user.id)}
  end

  def remove_user(user)
    $redis.with {|c| c.lrem(key_of_joined_user_ids, 0, user.id)}
  end

  # todo use pub sub
  def broadcast_timeout
    RoomChannel.event_timeout(self)
  end

  def add_ready_user(user)
    return if ready_user_ids.include? user.id
    $redis.with {|c| c.rpush(key_of_ready_user_ids, user.id)}
  end

  def add_winner(user)
    return if winner_ids.include? user.id
    $redis.with {|c| c.rpush(key_of_winner_ids, user.id)}
  end

  def are_all_users_ready?
    $redis.with do |c|
      c.llen(key_of_ready_user_ids) > 1 && c.llen(key_of_ready_user_ids) == c.llen(key_of_joined_user_ids)
    end
  end

  def are_all_users_guess_right?
    guess_user_count = $redis.with { |c| c.llen(key_of_joined_user_ids) - 1 }
    winners_count = $redis.with { |c| c.llen(key_of_winner_ids) }
    guess_user_count > 0 && guess_user_count == winners_count
  end

  def is_less_then_two_users?
    $redis.with { |c| c.llen(key_of_joined_user_ids) < 2 }
  end

  def is_only_one_user?
    $redis.with { |c| c.llen(key_of_joined_user_ids) == 1 }
  end

  def is_no_user?
    $redis.with { |c| c.llen(key_of_joined_user_ids) == 0 }
  end

  def is_painter?(user)
    painter_id == user.id
  end

  def can_accessed?(user)
    is_public || creator_id == user.id
  end

  def joined_users
    User.where(id: self.joined_user_ids)
  end

  def joined_count
    joined_user_ids.size
  end

  def ready_count
    ready_user_ids.size
  end

  def painter_id
    $redis.with { |c| c.get(key_of_drawing_user_id).to_i }
  end

  def painter
    User.find_by(id:painter_id)
  end

  def joined_user_ids
    $redis.with { |c| c.lrange(key_of_joined_user_ids, 0, -1).map(&:to_i) }
  end

  def ready_user_ids
    $redis.with { |c| c.lrange(key_of_ready_user_ids, 0, -1).map(&:to_i) }
  end

  def winner_ids
    $redis.with { |c| c.lrange(key_of_winner_ids, 0, -1).map(&:to_i) }
  end

  def set_answer(answer_text)
    $redis.with { |c| c.set(key_of_answer, answer_text) }
  end

  def answer
    $redis.with { |c| c.get key_of_answer }
  end

  def set_answer_hint(text)
    $redis.with { |c| c.set(key_of_answer_hint, text) }
  end

  def answer_hint
    $redis.with { |c| c.get key_of_answer_hint }
  end

  def current_game
    Game.find_by(id: self.current_game_id)
  end

  def current_game_id
    $redis.with { |c| c.get(key_of_game_id).to_i }
  end

  class << self
    def timers
      @timers ||= {}
    end

    def add_timer(room, timer)
      timers[room.id] = timer
    end

    def stop_timer(room)
      timer_task = timers[room.id]
      return unless timer_task
      timer_task.shutdown
      timers.delete room.id
    end
  end

  def start_timer(seconds)
    self.class.stop_timer self

    $redis.with { |c| c.set(key_of_timer_end_at, (Time.now.to_i + seconds).to_s) }
    task = Concurrent::TimerTask.new(execution_interval: seconds) do |t|
      t.shutdown
      self.emit_timeout!
    end
    task.execute

    self.class.add_timer(self, task)
  end

  def get_countdown
    countdown = $redis.with { |c| c.get(key_of_timer_end_at).to_i - Time.now.to_i }
    [countdown, 0].max
  end

  def stop_timer
    self.class.stop_timer(self)
    $redis.with { |c| c.del key_of_timer_end_at }
  end

  def add_operation(op)
    Game.add_operation(self.id, op)
  end

  def pop_operation
    get_operations.pop
  end

  def clear_operations
    Game.clear_operations(self.id)
  end

  def get_operations
    Game.get_operations(self.id)
  end

  def time_taken
    (Time.now.to_f + Constants::Room::COUNTDOWN_DRAW - $redis.with { |c| c.get(key_of_timer_end_at).to_i }).round(3)
  end

  private

  def key_of_joined_user_ids
    @key_of_joined_user_ids ||= "room_#{id}:user:ids"
  end

  def key_of_ready_user_ids
    @key_of_ready_user_ids ||= "room_#{id}:user:ready_ids"
  end

  def key_of_winner_ids
    @key_of_winner_ids ||= "room_#{id}:user:winner_ids"
  end

  def key_of_drawing_user_id
    @key_of_drawing_user_id ||= "room_#{id}:user:drawing_id"
  end

  def key_of_answer
    @key_of_answer ||= "room_#{id}:answer"
  end

  def key_of_answer_hint
    @key_of_answer_hint ||= "room_#{id}:answer_hint"
  end

  def key_of_timer_end_at
    @key_of_timer_end_at ||= "room_#{id}:timer_end_at"
  end

  def key_of_game_id
    @key_of_game_id ||= "room_#{id}:game_id"
  end
end
