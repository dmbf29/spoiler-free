class AddFontAwesomeClassToSports < ActiveRecord::Migration[8.1]
  def change
    add_column :sports, :font_awesome_class, :string
  end
end
