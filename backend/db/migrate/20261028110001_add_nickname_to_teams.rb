class AddNicknameToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :nickname, :string
  end
end
