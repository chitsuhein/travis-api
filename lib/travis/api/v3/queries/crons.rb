module Travis::API::V3
  class Queries::Crons < Query

    def find(repository)
      Models::Cron.where(branch_id: repository.branches)
    end

    def scheduled_crons
      Models::Cron.where("next_run <= '#{DateTime.now.utc}'")
    end
  end
end
