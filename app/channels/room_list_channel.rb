class RoomListChannel < ApplicationCable::Channel
  def subscribed
    stream_for "room_list"
  end

  def unsubscribed
  end
end