require 'travis/api/app/helpers/locking'

module Travis::API::V3
  class Services::Crons::Start < Service
    def run!
      loop do
        exclusive do
          time { enqueue_all }
        end
        # add metric to librato
        sleep(Cron::SCHEDULER_INTERVAL)
      end
    end

    def exclusive(&block)
      super('enqueue_cron_jobs', &block)
    end

    def query
      @query ||= Queries::Crons.new({}, 'Overview')
    end

    def enqueue_all
      query.scheduled_crons.each do |cron|
        begin
          cron.needs_new_build? ? cron.enqueue : cron.skip_and_schedule_next_build
        rescue => e
          Raven.capture_exception(e, tags: { 'cron_id' => cron.try(:id) })
          sleep(10) # This ensures the dyno does not spin down before the http request to send the error to sentry completes
          next
        end
      end
    end
  end
end
