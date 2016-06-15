module Tint
  class DecoratedAssociation < Draper::DecoratedAssociation
    def decorate
      association_chain = @association
      association_chain = Array.wrap(association_chain) unless association_chain.kind_of?(Array)

      associated = association_chain.inject(owner.object) do |memo, method_name|
        memo.send(method_name)
      end

      associated = associated.sent(scope) if scope

      @decorated = factory.decorate(associated, context_args: owner.context)
    end
  end
end
