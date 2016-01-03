require 'draper'
require_relative 'json_conversion.rb'

module Tint
  class Decorator < Draper::Decorator
    include JsonConversion

    def initialize(object, options = {})
      super(object, options)
    end

    def column_names
      object.class.column_names
    end

    def persisted?
      object.persisted?
    end

    class << self
      attr_accessor :_attributes, :eager_loads

      def attributes(*options)
        @_attributes ||= Set.new

        return unless options && options.any?

        mapped_attrs = options.extract_options!

        link_mappings_to_object(mapped_attrs)

        delegated_attrs = options

        link_delegations_to_object(delegated_attrs)
      end

      def eager_load(*schema)
        @_attributes ||= Set.new
        @eager_loads ||= []

        schema.each do |schema_item|
          @eager_loads.push(schema_item)
        end
      end

      def decorates_association(association_name, options = {})
        options[:with] ||= (association_name.to_s.camelize.singularize + 'Decorator').constantize

        super(association_name, options)

        attributes(association_name)
        association_eager_loads = options[:with].eager_loads

        if association_eager_loads.present?
          eager_load({ association_name =>  association_eager_loads})
        else
          eager_load(association_name)
        end
      end

      def decorates_associations(*arguments)
        options = arguments.extract_options!
        association_list = arguments

        association_list.each do |association_name|
          decorates_association(association_name, options.dup)
        end
      end

      def decorate_collection(collection, options = {})
        collection_with_eager_loads =
            if collection.respond_to?(:includes) && eager_loads.present?
              collection.includes(*eager_loads)
            else
              collection
            end

        super(collection_with_eager_loads, options)
      end

      def decorate(object, options = {})
        object_class = object.class

        unless already_eager_loaded_associations?(object)
          object =
              if responds_to_methods?(object_class, :includes, :find) && eager_loads.present?
                object_class.includes(*eager_loads).find(object.id)
              else
                object
              end
        end

        super(object, options)
      end

      private

      def already_eager_loaded_associations?(object)
        if object.respond_to?(:association_cache)
          object.association_cache.any?
        else
          true
        end
      end

      def responds_to_methods?(object, *methods)
        methods.each do |method_name|
          return false unless object.respond_to?(method_name)
        end

        true
      end

      def link_delegations_to_object(delegated_attrs)
        delegated_attrs.each do |delegate_method|
          @_attributes.add(delegate_method)

          unless method_defined?(delegate_method)
            define_method(delegate_method) do
              object.send(delegate_method)
            end
          end
        end
      end

      def link_mappings_to_object(mapped_attrs)
        mapped_attrs.each do |decorator_attribute, object_method|
          @_attributes.add(decorator_attribute)

          define_method(decorator_attribute) do
            object.send(object_method)
          end
        end
      end
    end


  end
end
