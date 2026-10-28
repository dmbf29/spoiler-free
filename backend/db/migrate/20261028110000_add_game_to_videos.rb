class AddGameToVideos < ActiveRecord::Migration[8.1]
  def change
    add_reference :videos, :game, null: true, foreign_key: true
  end
end
