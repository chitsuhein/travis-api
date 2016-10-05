require 'travis/api/v3/renderer/model_renderer'

module Travis::API::V3
  class Renderer::Cron < Renderer::ModelRenderer
    representation(:minimal,  :id)
    representation(:standard, :id, :repository, :branch, :interval, :run_only_when_new_commit, :last_run, :next_run, :created_at)

    def repository
      model.branch.repository
    end

  end
end
