require "mongoid"
require "mongoid/multitenancy/document"
require "mongoid/multitenancy/version"
require "mongoid/validators/tenant_validator"

module Mongoid
  module Multitenancy
    class << self

      # Returns true if using Mongoid 4
      def mongoid4?
        Mongoid::VERSION.start_with? '4'
      end

      # Set the current tenant. Make it Thread aware
      def current_tenant=(tenant)
        Thread.current[:current_tenant] = tenant
      end

      # Returns the current tenant
      def current_tenant
        Thread.current[:current_tenant]
      end

      # Won't throw error if no tenant is set
      def allow_no_tenant
        Thread.current[:allow_no_tenant]
      end

      def allow_no_tenant=(ant)
        Thread.current[:allow_no_tenant] = ant
      end

      # Affects a tenant temporary for a block execution
      def with_tenant(tenant, allow_no_tenant=false, &block)
        if block.nil?
          raise ArgumentError, "block required"
        end

        old_tenant = self.current_tenant
        old_allow_no_tenant = self.allow_no_tenant

        self.current_tenant = tenant
        self.allow_no_tenant = allow_no_tenant

        begin
          block.call
        ensure
          self.current_tenant = old_tenant
          self.allow_no_tenant = old_allow_no_tenant
        end
      end

    end
  end
end
