web: ./script/server
console: bundle exec je ./script/console
sidekiq: bundle exec je sidekiq -c 4 -r ./lib/travis/sidekiq.rb -q build_cancellations, -q build_restarts, -q job_cancellations, -q job_restarts
start_cron_service: ./bin/start_cron_service
