module Tint
  module JsonConversion
    def to_json(options={})
      as_json.to_json(options)
    end

    def as_json(options={})
      attributes_for_json
    end

    private

    module AttributeNameStrategy
      class Stringify
        class << self
          def transform(attribute_name)
            attribute_name.to_s
          end
        end
      end

      class Camelize
        class << self
          def transform(attribute_name)
            Stringify.transform(attribute_name).camelize(:lower)
          end
        end
      end

      class Snakize
        class << self
          def transform(attribute_name)
            Stringify.transform(attribute_name).underscore
          end
        end
      end

      class Kebabize
        class << self
          def transform(attribute_name)
            Stringify.transform(attribute_name).dasherize
          end
        end
      end
    end

    def attributes_for_json
      attribute_list = self.class._attributes
      override_methods = self.class._override_methods

      return {} if attribute_list.blank?

      strategy =
        case Tint.attribute_capitalization
        when :camel_case
          AttributeNameStrategy::Camelize
        when :snake_case
          AttributeNameStrategy::Snakize
        when :kebab_case
          AttributeNameStrategy::Kebabize
        else
          AttributeNameStrategy::Stringify
        end


      attribute_list.inject({}) do |memo, key_and_value|
        key, _ = key_and_value

        value =
          if override_methods[key]
            self.send(key)
          else
            self.object_attributes[key.to_s] || self.send(key)
          end

        unless value.nil?
          memo[strategy.transform(key)] = value.respond_to?(:as_json) ? value.as_json : value
        end

        memo
      end
    end
  end
end
