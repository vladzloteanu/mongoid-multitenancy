module Mongoid
  module Multitenancy
    module Errors
      class TenantNotSetError < StandardError; end
    end

    module Document
      extend ActiveSupport::Concern

      module ClassMethods
        attr_accessor :tenant_field, :full_indexes

        def tenant(association = :account, options = {})
          options = { full_indexes: true, force_tenant: false}.merge(options)
          active_model_options = options.clone
          to_index = active_model_options.delete(:index)
          force_tenant = active_model_options.delete(:force_tenant)
          tenant_options = { optional: active_model_options.delete(:optional), immutable: active_model_options.delete(:immutable) { true } }
          self.full_indexes = active_model_options.delete(:full_indexes)

          # Setup the association between the class and the tenant class
          belongs_to association, active_model_options

          # Get the tenant model and its foreign key
          tenant_field = reflect_on_association(association).foreign_key
          self.tenant_field = tenant_field

          # Validates the tenant field
          validates tenant_field, tenant: tenant_options

          # Set the current_tenant on newly created objects
          before_validation lambda { |m|
            if Multitenancy.current_tenant and !tenant_options[:optional] and m.send(association.to_sym).nil?
              m.send "#{association}=".to_sym, Multitenancy.current_tenant
            end
            true
          }

          # Set the default_scope to scope to current tenant
          default_scope lambda {
            if Multitenancy.current_tenant
              if tenant_options[:optional]
                #any_of({ self.tenant_field => Multitenancy.current_tenant.id }, { self.tenant_field => nil })
                where({ tenant_field.to_sym.in => [Multitenancy.current_tenant.id, nil] })
              else
                where({ tenant_field => Multitenancy.current_tenant.id })
              end
            elsif force_tenant and not Multitenancy.allow_no_tenant
              raise Multitenancy::Errors::TenantNotSetError, "No tenant set for #{self}"
            else
              where(nil)
            end
          }

          self.define_singleton_method(:inherited) do |child|
            child.tenant association, options
            super(child)
          end

          if to_index
            index({self.tenant_field => 1}, { background: true })
          end
        end

        # Redefine 'validates_with' to add the tenant scope when using a UniquenessValidator
        def validates_with(*args, &block)
          validator = if Mongoid::Multitenancy.mongoid4?
            Validatable::UniquenessValidator
          else
            Validations::UniquenessValidator
          end

          if args.first.ancestors.include?(validator)
            args.last[:scope] = Array(args.last[:scope]) << self.tenant_field
          end
          super(*args, &block)
        end

        # Redefine 'index' to include the tenant field in first position
        def index(spec, options = nil)
          spec = { self.tenant_field => 1 }.merge(spec) if self.full_indexes
          super(spec, options)
        end

        # Redefine 'delete_all' to take in account the default scope
        def delete_all(conditions = nil)
          scoped.where(conditions).delete
        end
      end
    end
  end
end
