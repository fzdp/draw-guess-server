class V1::RoomsController < ApplicationController
  skip_before_action :validate_token, only: [:index]
  before_action :validate_access, only: [:show, :auth]

  def index
    rooms = Room.accessed_by(current_user).includes(:creator).order(id: :desc)
    public_rooms, private_rooms = rooms.partition &:is_public?
    render json: { data: { public: public_rooms, private: private_rooms } }
  end

  def update
    @room = Room.find_by(id: params[:id])
    if @room.creator_id != current_user.id
      render json: { error: "更新失败，你不是房间的创建者" }, status: :bad_request
    end

    if @room.update room_params
      render json: { data: "更新成功" }
    else
      render json: { error: @room.errors }
    end
  end

  def show
    render json: { data: @room }
  end

  def auth
    render json: { data: { success: true } }
  end

  def create
    ActionRateLimiter.check!(Constants::RateLimit::CREATE_ROOM, current_user)

    room = Room.new room_params
    if room.is_public?
      created_count = current_user.created_rooms.is_public.count
      if created_count >= Constants::Room::PUBLIC_MAX_COUNT
        render json: { error: "您的公开房间数量已经达到上限" }, status: :not_acceptable and return
      end
    else
      created_count = current_user.created_rooms.is_private.count
      if created_count >= Constants::Room::PRIVATE_MAX_COUNT
        render json: { error: "您的私人房间数量已经达到上限" }, status: :not_acceptable and return
      end
    end

    room.creator_id = current_user.id
    if room.save
      if room.is_public
        ActiveSupport::Notifications.instrument "game_lobby.created", room: room
      end
      render json: { data: room }
    else
      render json: { error: room.errors }
    end
  end

  private

  def room_params
    params.require(:room).permit(:name, :is_public, :id, :password)
  end

  def validate_access
    @room = Room.find_by(id: params[:id])
    if !@room.can_accessed?(current_user) && (@room.password != params[:room][:password])
      render json: { error: "无法访问此房间" }
    end
  rescue
    render json: { error: "无法访问此房间" }
  end
end
