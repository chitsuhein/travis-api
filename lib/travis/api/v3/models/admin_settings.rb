require_relative './json_slice'

module Travis::API::V3
  class Models::AdminSettings < Models::JsonSlice
    pair Models::AdminSetting
    attribute :api_builds_rate_limit, Integer
  end
end
