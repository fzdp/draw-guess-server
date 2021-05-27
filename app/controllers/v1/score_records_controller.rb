class V1::ScoreRecordsController < ApplicationController
  def index
    @total_records = current_user.score_records.order(created_at: :desc)
    render json: { data: @total_records }
  end
end