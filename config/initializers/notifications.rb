ActiveSupport::Notifications.subscribe "game_lobby.created" do |event|
  RoomListChannel.broadcast_to "room_list", event: "created", data: event.payload[:room]
end

ActiveSupport::Notifications.subscribe "game_lobby.joined" do |event|
  RoomListChannel.broadcast_to "room_list", event: "joined", data: event.payload[:room]
end

ActiveSupport::Notifications.subscribe "game_lobby.leaved" do |event|
  RoomListChannel.broadcast_to "room_list", event: "leaved", data: event.payload[:room]
end