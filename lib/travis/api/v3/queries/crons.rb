module Travis::API::V3
  class Queries::Crons < Query

    def find(repository)
      Models::Cron.where(branch_id: repository.branches)
    end

    def enqueue_all
      scheduled_crons.each do |cron|
        begin
          cron.needs_new_build? ? cron.enqueue : cron.skip
        rescue => e
          Raven.capture_exception(e, tags: { 'cron_id' => cron.try(:id) })
          sleep(10) # This ensures the dyno does not spin down before the http request to send the error to sentry completes
          next
        end
      end
    end

    def scheduled_crons
      Models::Cron.where("next_run <= '#{DateTime.now.utc}'")
    end
  end
end
