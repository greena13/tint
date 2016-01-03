module Tint
  class << self
    attr_accessor :attribute_capitalization

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
