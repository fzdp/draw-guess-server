class GameScoreCalculator
  def self.call(room, time_taken)
    winner_size = room.winner_ids.size
    score = {1 => 30, 2 => 20, 3 => 10}.fetch(winner_size, 5)
    if time_taken <= 15
      score += 10
    elsif time_taken <= 45
      score += 5
    end

    score
  end
end