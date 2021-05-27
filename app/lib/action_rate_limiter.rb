class ActionRateLimiter
  class TooManyRequestsError < StandardError; end

  class ActionItem
    def initialize(action, options, identified_by)
      @action = action
      @limit = options.fetch(:limit) { raise "limit option missing" }
      @period = options.fetch(:period) { raise "period option missing" }
      @block_time = options.fetch(:block_time, ActionRateLimiter.block_time)
      @refresh_block = options.fetch(:refresh_block, ActionRateLimiter.refresh_block)
      @error_message = options.fetch(:error_message, ActionRateLimiter.error_message)
      @identified_by = identified_by
    end

    def check!(*args)
      check?(*args) or raise ::ActionRateLimiter::TooManyRequestsError.new(@error_message)
    end

    def check?(*args)
      action_identifier = get_action_identifier(*args)
      blocked_key = get_blocked_key(action_identifier)

      if $redis.with { |c| c.exists?(blocked_key) }
        if @refresh_block
          $redis.with { |c| c.set(blocked_key, "#{Time.now.to_i}", ex: @block_time) }
        end
        return false
      end

      counter_key = get_count_key(action_identifier)
      $redis.with { |c| c.set(counter_key, "0", ex: @period, nx: true) }
      if $redis.with { |c| c.incr(counter_key) } <= @limit
        return true
      end

      $redis.with do |c|
        c.multi do |m|
          m.set(blocked_key, "#{Time.now.to_i}", ex: @block_time)
          m.del counter_key
        end
      end

      false
    end

    def reset(*args)
      action_identifier = get_action_identifier(*args)
      $redis.with { |c| c.del(get_blocked_key(action_identifier), get_count_key(action_identifier)) }
    end

    private

    def get_count_key(identifier)
      "arl:count:#{@action}:#{identifier}"
    end

    def get_blocked_key(identifier)
      "arl:blocked:#{@action}:#{identifier}"
    end

    def get_action_identifier(*args)
      identifier = @identified_by.call(*args)
      identifier.present? ? identifier : raise("action identifier required")
    end
  end

  class << self
    attr_accessor :block_time, :error_message, :refresh_block

    # add "send_email", limit: 60, period: 1.minutes, block_time: 30 { |user| user.id }
    def add(action, options, &identified_by)
      raise "action required" if action.blank?
      raise "identified_by required" if identified_by.blank?

      action_items[action] = ActionItem.new(action, options, identified_by)
      self
    end

    def check!(action, *args)
      action_items[action].check!(*args)
    end

    def check?(action, *args)
      action_items[action].check?(*args)
    end

    def reset(action, *args)
      action_items[action].reset(*args)
    end

    private

    def action_items
      @_action_items ||= {}
    end
  end

  @block_time = 60
  @error_message = "请求过于频繁，请稍后重试"
  @refresh_block = false

  def initialize(app)
    @app = app
  end

  def call(env)
    if self.class.check?(Constants::RateLimit::GENERAL_REQUEST, ActionDispatch::Request.new(env))
      @app.call(env)
    else
      [429, {'Content-Type' => 'application/json'}, [{ error: self.class.error_message }.to_json]]
    end
  end
end
