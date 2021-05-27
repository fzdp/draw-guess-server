class AvatarGenerationJob < ApplicationJob
  queue_as :urgent

  def perform(*users)
    users.each do |user|
      AvatarGenerator.new(user).call
    end
  end
end