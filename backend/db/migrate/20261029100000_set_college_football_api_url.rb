# The schedule sync reads its ESPN base URL from Competition#api_url. Seeds set
# it, but production isn't re-seeded on deploy, so set it here too.
class SetCollegeFootballApiUrl < ActiveRecord::Migration[8.1]
  ESPN_URL = "https://site.api.espn.com/apis/site/v2/sports/football/college-football".freeze

  def up
    execute <<~SQL
      UPDATE competitions SET api_url = '#{ESPN_URL}'
      WHERE slug = 'college-football' AND (api_url IS NULL OR api_url = '')
    SQL
  end

  def down; end
end
