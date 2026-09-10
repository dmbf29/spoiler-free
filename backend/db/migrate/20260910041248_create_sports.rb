class CreateSports < ActiveRecord::Migration[8.1]
  def change
    create_table :sports do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end
    add_index :sports, :slug, unique: true
  end
end
