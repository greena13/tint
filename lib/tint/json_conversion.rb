module Tint
  module JsonConversion
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

    def remove_js_unsafe_chars(string)
      string.gsub(/[\u007f-\u009f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/, '')
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
          json_value = value.respond_to?(:as_json) ? value.as_json : value

          memo[strategy.transform(key)] = json_value.kind_of?(String) ? remove_js_unsafe_chars(json_value) : json_value
        end

        memo
      end
    end
  end
end
