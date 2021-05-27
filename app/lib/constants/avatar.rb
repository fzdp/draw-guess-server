module Constants
  module Avatar
    DEFAULT_WIDTH = 200
    THUMB_WIDTH = 64
    FONT_SIZE = 80
    LARGE_FONT_SIZE = 120
    DEFAULT_FILE_NAME = "%s.jpg"
    THUMB_FILE_NAME = "%s_#{THUMB_WIDTH}.jpg"
    BACKGROUND_COLORS = %w(#1eae98 #233e8b #b6c9f0 #9fe6a0 #939b62 #77acf1 #5b6d5b #a799b7 #a3d2ca #9e9d89 #cdc733
#e9b0df #c0e218 #a685e2 #61b15a #c6b497 #389393 #9ab3f5 #8d93ab #81b214 #fddb3a #00bcd4 #d3de32 #e79cc2 #96bb7c).freeze
    TEXT_COLORS = %w(#f9fcfb #393e46).freeze
    FONT = Rails.public_path.join("avatar_font.ttf")
  end
end