# Needs to be changed
namespace :db do
  desc "Drops the development DB and replaces it with the SUPABASE production DB"
  task pull: :environment do
    source = ENV.fetch("SUPABASE_DATABASE_URL") # full SUPABASE service URI, keep ?sslmode=require
    target = "spoiler_free_development"

    puts "-----> Setting the environment..."
    run "RAILS_ENV=development rails db:environment:set"

    puts "-----> dropping & recreating the local DB..."
    run "rails db:drop db:create"

    puts "-----> pulling the DB from SUPABASE..."
    # --schema=public: Supabase provisions auth/storage/extensions/realtime/vault
    # schemas with extensions (pgsodium, pg_graphql, pg_net...) that aren't
    # installed locally. A full-database dump would try to recreate those and
    # abort the whole restore under ON_ERROR_STOP=1 before reaching our tables.
    # --no-publications: skip the supabase_realtime publication, unrelated to us.
    # --clean --if-exists: emit DROP ... IF EXISTS before each CREATE, since the
    # freshly created target db already has the default (empty) public schema —
    # without this, pg_dump's own `CREATE SCHEMA public;` fails immediately.
    # pg_dump 17+ emits `SET transaction_timeout` (unknown to the local PG 15 server); strip it.
    run %(bash -c 'set -o pipefail; pg_dump --no-owner --no-privileges --no-comments --no-publications --schema=public --clean --if-exists "#{source}" | sed -e "/^SET transaction_timeout/d" | psql --quiet --set ON_ERROR_STOP=1 "#{target}"')
  end

  def run(cmd)
    system(cmd)
    return if $?.success?

    # Redact any credentials embedded in a connection URI (postgresql://user:pass@host)
    # before they end up in a terminal, log file, or CI output.
    redacted = cmd.gsub(%r{(://[^:/@\s]+):[^@/\s]+@}, '\1:REDACTED@')
    raise "Command #{redacted.inspect} failed!"
  end
end
