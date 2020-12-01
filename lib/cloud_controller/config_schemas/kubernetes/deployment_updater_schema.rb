require 'vcap/config'
require 'cloud_controller/config_schemas/deployment_updater_schema'

module VCAP::CloudController
  module ConfigSchemas
    module Kubernetes
      class DeploymentUpdaterSchema < VCAP::Config
        self.parent_schema = VCAP::CloudController::ConfigSchemas::DeploymentUpdaterSchema

        delegate :configure_components, to: :parent_schema

        define_schema do
          {
            kubernetes: {
              host_url: String,
              service_account: {
                token_file: String,
              },
              ca_file: String,
              workloads_namespace: String,
            },
          }
        end
      end
    end
  end
end
