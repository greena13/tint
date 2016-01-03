module Tint
  class << self
    attr_accessor :camelize_attribute_names

    def configuration
      if block_given?
        yield(Tint)
      end
    end

    alias :config :configuration
  end

  @attribute_capitalization = :camel_case
end

require "tint/version"
require "tint/decorator"
