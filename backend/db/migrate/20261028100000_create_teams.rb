class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :espn_id, null: false
      t.string :name, null: false
      t.string :short_name, null: false
      t.string :abbreviation
      t.string :logo_url
      t.string :color
      t.string :conference
      t.timestamps
    end
    add_index :teams, :espn_id, unique: true
  end
end
