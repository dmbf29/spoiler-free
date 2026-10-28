class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :competition, null: false, foreign_key: true
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.string :espn_id, null: false
      t.integer :season, null: false
      t.integer :season_type, null: false, default: 2
      t.integer :week
      t.datetime :kickoff_at, null: false
      t.boolean :neutral_site, null: false, default: false
      t.string :tv
      t.string :status, null: false, default: "scheduled"
      # Pre-game AP/CFP rank, snapshotted only while the game is still
      # scheduled: once a game is played the live rank can reveal the result.
      t.integer :home_rank
      t.integer :away_rank
      t.timestamps
    end
    add_index :games, :espn_id, unique: true
    add_index :games, :kickoff_at
    add_index :games, %i[competition_id season season_type week]
  end
end
