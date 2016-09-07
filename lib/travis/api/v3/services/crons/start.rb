require "core_ext/kernel/run_periodically"

module Travis::API::V3
  class Services::Crons::Start < Service
    def run!
      run_periodically(Travis::API::V3::Cron::SCHEDULER_INTERVAL) do
        query.enqueue_all
      end
    end
  end
end
