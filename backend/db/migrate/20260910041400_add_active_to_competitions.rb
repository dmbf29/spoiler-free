class AddActiveToCompetitions < ActiveRecord::Migration[8.1]
  def change
    # Whether this competition is classified/displayed yet. Lets us seed future
    # competitions (Champions League, College Football) without exposing them.
    add_column :competitions, :active, :boolean, null: false, default: false
  end
end
