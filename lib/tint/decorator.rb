require 'draper'
require 'deep_merge/rails_compat'
require_relative 'json_conversion.rb'

require 'tint/decorated_association'

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
        self.eager_loads = self.eager_loads.deeper_merge(expand_schema(schema))
      end

      def decorates_association(*args)
        options = args.extract_options!
        association_chain = args

        association_tail = association_chain.last

        options[:with] ||= (association_tail.to_s.camelize.singularize + 'Decorator').constantize

        association_alias = options.delete(:as) || association_tail

        options.assert_valid_keys(:with, :scope, :context)

        define_association_method(association_alias, association_chain, options)

        eager_load_association(association_chain, options)
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
                object_class.includes(eager_loads).find(object.id)
              else
                object
              end
        end

        super(object, options)
      end

      def parent_eager_loads_include_own?(context = {})

        if context && context[:parent_decorator]
          if (parent_eager_loads = context[:parent_decorator].class.eager_loads)

            association_eager_load =
              context[:parent_association].inject(parent_eager_loads) do |memo, chain_link|
                memo[chain_link] if memo
              end

            !!association_eager_load
          end
        else
          false
        end
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

      private

      def expand_schema(schema)
        if schema.kind_of?(Hash)
          schema.inject({}) do |memo, (schema_key, schema_value)|
            memo[schema_key] = expand_schema(schema_value)
            memo
          end
        elsif schema.kind_of?(Array)
          schema.inject({}) do |memo, schema_item|
            memo.merge(expand_schema(schema_item))
          end
        else
          { schema => {} }
        end
      end

      def define_association_method(association_alias, association_chain, options)
        define_method(association_alias) do
          context_with_association = context.merge({
               parent_decorator: self,
               parent_association: association_chain
           })

          decorated_associations[association_alias] ||= Tint::DecoratedAssociation.new(
              self,
              association_chain,
              options.merge(context: context_with_association)
          )

          decorated_associations[association_alias].call
        end

        attributes(association_alias)
      end

      def eager_load_association(association_chain, options)
        association_eager_loads = options[:with].eager_loads
        schema = association_schema(association_chain, association_eager_loads)

        eager_load(schema)
      end

      def association_schema(association_chain, eager_loads = {})
        association_chain.reverse.reduce({}) do |memo, chain_link|

          if chain_link == association_chain.last
            { chain_link => eager_loads }
          else
            { chain_link => memo }
          end
        end
      end
    end

  end

end
