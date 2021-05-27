module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :guest_id

    def connect
      token = request.params[:token]
      if token.present?
        self.current_user = find_user_by_token(token)
      else
        guest_id = request.params[:guest_id]
        if guest_id
          self.guest_id = guest_id
        else
          reject_unauthorized_connection
        end
      end
    end

    private

    def find_user_by_token(token)
      begin
        payload = JsonWebToken.decode token
        User.find(payload.fetch(:user_id, nil))
      rescue
        reject_unauthorized_connection
      end
    end
  end
end
