class AddRegionRestrictionToVideos < ActiveRecord::Migration[8.1]
  # Stores the raw YouTube `contentDetails.regionRestriction` hash
  # ({ "allowed" => [...] } or { "blocked" => [...] }), or NULL when the upload
  # has no restriction. The existing `region_restricted` boolean stays as the
  # cheap "is it restricted at all" flag.
  def up
    add_column :videos, :region_restriction, :jsonb

    # Backfill from the payload we already store on every synced row.
    execute(<<~SQL.squish)
      UPDATE videos
         SET region_restriction = raw_payload #> '{contentDetails,regionRestriction}'
       WHERE raw_payload #> '{contentDetails,regionRestriction}' IS NOT NULL
    SQL
  end

  def down
    remove_column :videos, :region_restriction
  end
end
