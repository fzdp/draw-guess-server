class GameScoreGenerationJob < ApplicationJob
  queue_as :urgent

  def perform(room, user, painter, **options)
    game_id = room.current_game_id

    User.transaction do
      user.update_column :score, user.score + options[:score]
      user.score_records.create(
          score: options[:score], total_score: user.score, game_id: game_id, room_id: room.id,
          reason: ScoreRecord.reasons[:guess_right], time_taken: options[:time_taken]
      )

      painter.update_column :score, painter.score + Constants::Room::PAINTER_SCORE_ON_GUESS_RIGHT
      painter.score_records.create(
          score: Constants::Room::PAINTER_SCORE_ON_GUESS_RIGHT, total_score: painter.score, game_id: game_id,
          reason: ScoreRecord.reasons[:draw_right], time_taken: options[:time_taken], room_id: room.id
      )
    end
  end
end