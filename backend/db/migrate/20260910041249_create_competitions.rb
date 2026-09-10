class CreateCompetitions < ActiveRecord::Migration[8.1]
  def change
    create_table :competitions do |t|
      t.string :name, null: false
      t.string :slug, null: false
      # Human/dev note describing how this competition's highlight videos are
      # titled on YouTube (used to build/verify classifier rules).
      t.string :video_naming_convention
      # Reserved for V3: URL of a schedule/fixtures API for this competition.
      t.string :api_url
      t.references :sport, null: false, foreign_key: true

      t.timestamps
    end
    add_index :competitions, :slug, unique: true
  end
end
