class Game < ApplicationRecord
  belongs_to :room
  has_many :score_records

  class << self
    def total_operations
      @total_operations ||= {}
    end

    def get_operations(room_id)
      total_operations[room_id] or (total_operations[room_id] = [])
    end

    def add_operation(room_id, operation)
      get_operations(room_id).append(operation)
    end

    def clear_operations(room_id)
      total_operations.delete room_id
    end
  end

  def artwork_url
    "//#{Constants::App::IMAGE_HOST}/#{artwork_id}.png"
  end
end
