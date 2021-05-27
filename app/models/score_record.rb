class ScoreRecord < ApplicationRecord
  belongs_to :user
  belongs_to :game, optional: true
  belongs_to :room, optional: true

  enum reason: {
      guess_right: "guess_right",
      draw_right: "draw_right"
  }

  def as_json(options={})
    default_options = {only: [:id, :score, :total_score, :created_at], methods: [:reason_detail]}
    super(default_options.merge(options))
  end

  def reason_detail
    if self.guess_right?
      "猜对答案"
    elsif self.draw_right?
      "其他玩家猜中"
    end
  end
end
