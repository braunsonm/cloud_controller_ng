require 'vcap/config'
require 'cloud_controller/resource_pool'
require 'cloud_controller/config_schemas/api_schema'

module VCAP::CloudController
  module ConfigSchemas
    module Kubernetes
      class ApiSchema < VCAP::Config
        self.parent_schema = VCAP::CloudController::ConfigSchemas::ApiSchema

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
              kpack: {
                builder_namespace: String,
                registry_service_account_name: String,
                registry_tag_base: String,
              }
            },
          }
        end
      end
    end
  end
end
