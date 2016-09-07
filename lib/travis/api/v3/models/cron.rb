module Travis::API::V3
  class Models::Cron < Model

    belongs_to :branch
    after_create :schedule_first_build

    TIME_INTERVALS = {
      "daily"   => :day,
      "weekly"  => :week,
      "monthly" => :month
    }

    def schedule_next_build(from: nil)
      update_attribute(:next_run, (from || last_run || DateTime.now.utc) + 1.send(TIME_INTERVALS[interval]))
    end

    def schedule_first_build
      update_attribute(:next_run, DateTime.now.utc + Cron::SCHEDULER_INTERVAL)
    end

    def needs_new_build?
      always_run? || (last_non_cron_build_time > (last_run || created_at))
    end

    def skip
      schedule_next_build(from: last_non_cron_build_time)
    end

    def enqueue
      raise ServerError, 'repository does not have a github_id'.freeze unless branch.repository.github_id
      unless branch.exists_on_github
        self.destroy
        return false
      end

      user_id = branch.repository.users.detect { |u| u.github_oauth_token }.try(:id)
      user_id ||= branch.repository.owner.id

      payload = {
        repository: {
          id: branch.repository.github_id,
          owner_name: branch.repository.owner_name,
          name: branch.repository.name },
        branch:     branch.name,
        user:       { id: user_id }
      }

      class_name, queue = Query.sidekiq_queue(:build_request)
      ::Sidekiq::Client.push('queue'.freeze => queue, 'class'.freeze => class_name, 'args'.freeze => [{type: 'cron'.freeze, payload: JSON.dump(payload), credentials: {}}])

      update_attribute(:last_run, DateTime.now.utc)
      schedule_next_build
    end

    private
    def always_run?
      !run_only_when_new_commit
    end

    def last_non_cron_build_time
      Build.find_by_id(branch.last_build_id).finished_at.to_datetime.utc
    end
  end
end
