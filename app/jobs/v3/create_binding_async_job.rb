require 'jobs/reoccurring_job'
require 'actions/service_route_binding_create'
require 'actions/service_credential_binding_create'
require 'jobs/v3/create_route_binding_job'
require 'jobs/v3/create_service_credential_binding_job'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class CreateBindingAsyncJob < Jobs::ReoccurringJob
      def initialize(type, precursor_guid, parameters:, user_audit_info:, audit_hash:)
        super()
        @resource_guid = precursor_guid
        @user_audit_info = user_audit_info
        @parameters = parameters
        @audit_hash = audit_hash
        @first_time = true
        @type = type
      end

      def actor
        @actor ||= if @type == :route
                     CreateRouteBindingJob.new(@resource_guid, parameters: @parameters, user_audit_info: @user_audit_info)
                   else
                     CreateServiceCredentialBindingJob.new(@resource_guid, parameters: @parameters, user_audit_info: @user_audit_info, audit_hash: @audit_hash)
        end
      end

      def operation
        :bind
      end

      def operation_type
        'create'
      end

      def max_attempts
        1
      end

      def display_name
        actor.display_name
      end

      def resource_guid
        @resource_guid
      end

      def resource_type
        actor.resource_type
      end

      def perform
        ###
        # TODO: use this in the controller
        # TODO: implement #action in the jobs
        # TODO: change poll to return the hash with {finished and retry_after}
        # TODO: implement get_resource in the action
        # TODO: eventually move the errors being rescued into their own files
        ###
        resource = actor.get_resource(resource_guid)
        gone! unless resource

        action = actor.new_action
        compute_maximum_duration

        if @first_time
          @first_time = false
          action.bind(resource, parameters: @parameters, accepts_incomplete: true)

          return finish if resource.reload.terminal_state?
        end

        polling_status = action.poll(resource)

        if polling_status[:finished] == true
          finish
        end

        if polling_status[:retry_after].present?
          self.polling_interval_seconds = polling_status[:retry_after]
        end
      rescue ServiceRouteBindingCreate::BindingNotRetrievable
        raise CloudController::Errors::ApiError.new_from_details('ServiceBindingInvalid', 'The broker responded asynchronously but does not support fetching binding data')
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'bind', e.message)
      end

      def handle_timeout
        route_binding.save_with_new_operation(
          {},
          {
            type: operation_type,
            state: 'failed',
            description: "Service Broker failed to #{operation} within the required time.",
          }
        )
      end

      private

      def route_binding
        RouteBinding.first(guid: @resource_guid)
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = route_binding.service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan
      end

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "The binding could not be found: #{@resource_guid}")
      end
    end
  end
end
