require "core_ext/kernel/run_periodically"

module Travis::API::V3
  class Services::Crons::Start < Service
    def run!
      Travis.logger.info "DB connection to: #{ActiveRecord::Base.connection.current_database}"
      Travis.logger.info "Ready to run crons"
      run_periodically(Travis::API::V3::Cron::SCHEDULER_INTERVAL) do
        begin
          enqueue_all
        rescue Exception => error
          puts "Query for finding scheduled crons crashed with message #{error.message}."
          Travis.logger.error "Query for finding scheduled crons crashed with message #{error.message}."
        end
      end
    end

    def query
      @query ||= Queries::Crons.new({}, 'Overview')
    end

    def enqueue_all
      Travis.logger.info "Enqueuing "
      Travis.logger.info "#{query.scheduled_crons.count} jobs now"
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
