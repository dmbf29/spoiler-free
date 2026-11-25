# ESPN fills undecided playoff/bowl slots with "TBD" teams (negative espn_ids).
# Espn::Event#complete? now skips those games; remove the ones already synced.
# They come back with real teams under the same espn_id once the matchup is set.
class RemoveTbdPlaceholderGames < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE videos SET game_id = NULL WHERE game_id IN (
        SELECT games.id FROM games
        JOIN teams home ON home.id = games.home_team_id
        JOIN teams away ON away.id = games.away_team_id
        WHERE home.espn_id LIKE '-%' OR away.espn_id LIKE '-%'
      )
    SQL
    execute <<~SQL
      DELETE FROM games WHERE home_team_id IN (SELECT id FROM teams WHERE espn_id LIKE '-%')
         OR away_team_id IN (SELECT id FROM teams WHERE espn_id LIKE '-%')
    SQL
    execute "DELETE FROM teams WHERE espn_id LIKE '-%'"
  end

  def down; end
end
