class GameCanvasProcessingJob < ApplicationJob
  SAVE_DIR = Rails.env.development? ? Rails.public_path.join("artworks") : Rails.application.credentials.artworks_dir

  queue_as :normal

  def perform(game_id, painter_id, width, height, base64_data)
    game = Game.find game_id
    painter = User.find painter_id
    artwork_id = "@#{painter.username}/#{SecureRandom.hex(10)}"

    if base64_data.present?
      begin
        content_type, _, image_data = base64_data.split(/[:;,]/)[1..3]
        image_data = Base64.decode64(image_data)
        image_type = content_type.split('/')[1]

        save_dir = "#{SAVE_DIR}/@#{painter.username}"
        FileUtils.mkdir save_dir unless File.exists?(save_dir)

        save_path = "#{SAVE_DIR}/#{artwork_id}.#{image_type}"
        File.open(save_path, "wb") do |f|
          f.write image_data
        end
      rescue => e
        artwork_id = nil
      end
    end

    game.update(canvas_width: width, canvas_height: height, artwork_id: artwork_id)
  end
end