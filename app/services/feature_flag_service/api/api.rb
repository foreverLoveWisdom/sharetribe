module FeatureFlagService::API
  class API

    def self.features
      @features ||= FeatureFlagService::API::Features.new(
        FeatureFlagService::Store::CachingFeatureFlag.new(additional_flags: [])
      )
    end
  end
end
