require 'draper'
require 'deep_merge/rails_compat'
require_relative 'json_conversion.rb'

module Tint
  class Decorator < Draper::Decorator
    include JsonConversion

    def initialize(object, options = {})
      super(object, options.except(:parent_decorator, :parent_association))

      @context = @context.merge(options.slice(:parent_decorator, :parent_association))
    end

    def column_names
      object.class.column_names
    end

    def persisted?
      object.persisted?
    end

    def decorate_as_association(association_name, association, options = {})
      options.assert_valid_keys(:with)

      association_decorator = options[:with]

      association_context = options.except(:with).merge(context: context.
          merge(parent_decorator: self, parent_association: association_name.to_sym))

      self.class.eager_load(association_name => {})

      if association.respond_to?(:each)
        association_decorator.decorate_collection(association, association_context)
      else
        association_decorator.decorate(association, association_context)
      end
    end

    class << self
      attr_accessor :_attributes, :parent_decorator, :parent_association

      def eager_loads
        {}
      end

      def eager_loads=(value)
        singleton_class.class_eval do
          remove_possible_method(:eager_loads)

          define_method(:eager_loads){
            value
          }
        end
      end

      def attributes(*options)
        @_attributes ||= Set.new

        return unless options && options.any?

        mapped_attrs = options.extract_options!

        link_mappings_to_object(mapped_attrs)

        delegated_attrs = options

        link_delegations_to_object(delegated_attrs)
      end

      def eager_load(*schema)
        new_eager_loads =
          schema.inject({}) do |memo, schema_item|
            if schema_item.kind_of?(Hash)
              memo = memo.merge(schema_item)
            else
              memo[schema_item] = {}
            end

            memo
          end

        self.eager_loads = self.eager_loads.deeper_merge(new_eager_loads)
      end

      def decorates_association(association_name, options = {})
        options[:with] ||= (association_name.to_s.camelize.singularize + 'Decorator').constantize

        association_alias = options.delete(:as) || association_name

        options.assert_valid_keys(:with, :scope, :context)

        define_method(association_alias) do
          context_with_association = context.merge({
              parent_decorator: self,
              parent_association: association_name
          })

          decorated_associations[association_alias] ||= Draper::DecoratedAssociation.new(
              self,
              association_name,
              options.merge(context: context_with_association)
          )

          decorated_associations[association_alias].call
        end

        attributes(association_alias)

        association_eager_loads = options[:with].eager_loads

        if association_eager_loads.present?
          eager_load({ association_name => association_eager_loads})
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
          if collection.respond_to?(:includes) &&
            eager_loads.present?  &&
             !parent_eager_loads_include_own?(options[:context])

            collection.includes(eager_loads)
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

      def parent_eager_loads_include_own?(context = {})
        !!(context && context[:parent_decorator] && context[:parent_decorator].class.eager_loads[context[:parent_association]])
      end

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
              if object.respond_to?(delegate_method)
                object.send(delegate_method)
              end
            end
          end
        end
      end

      def link_mappings_to_object(mapped_attrs)
        mapped_attrs.each do |decorator_attribute, object_method|
          @_attributes.add(decorator_attribute)

          define_method(decorator_attribute) do
            if object.respond_to?(object_method)
              object.send(object_method)
            end
          end
        end
      end
    end

  end

end
