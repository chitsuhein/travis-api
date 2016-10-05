module Travis::API::V3
  class Queries::Cron < Query
    params :id

    sortable_by :id

    def find
      return Models::Cron.find_by_id(id) if id
      raise WrongParams, 'missing cron.id'.freeze
    end

    def find_for_branch(branch)
      branch.cron
    end

    def create(branch, interval, run_only_when_new_commit)
      branch.cron.destroy unless branch.cron.nil?
      Models::Cron.create(branch: branch, interval: interval, run_only_when_new_commit: run_only_when_new_commit)
    end
  end
end
