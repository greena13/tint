require 'tint'
require_relative '../support/active_record_mock'

RSpec.describe Tint::Decorator do
  subject{ decorator_class.decorate(object).as_json }

  let(:object_class) do
    Class.new(ActiveRecordMock) do
      attr_reader :attr1, :attr2

      def initialize(attr1, attr2)
        @attr1, @attr2 = attr1, attr2
      end
    end
  end

  let(:object) { object_class.new('one', 'two') }

  describe "::attributes" do
    context "when only delegations are defined" do
      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          attributes :attr1, :attr2
        end
      end

      it "delegates attributes of the same name to the object" do
        expect(subject['attr1']).to eql('one')
        expect(subject['attr2']).to eql('two')
      end
    end

    context "when delegations and mappings are defined" do
      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          attributes :attr1, decorated1: :attr2
        end
      end

      it "delegates attributes of the same name to the object" do
        expect(subject['attr1']).to eql('one')
        expect(subject['decorated1']).to eql('two')
      end
    end

    context "when only mappings are defined" do
      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          attributes decorated1: :attr1, decorated2: :attr2
        end
      end

      it "delegates attributes of the same name to the object" do
        expect(subject['decorated1']).to eql('one')
        expect(subject['decorated2']).to eql('two')
      end
    end
  end

  describe "::decorates_association" do
    let(:associated_decorator) do
      Class.new(Tint::Decorator) do
        attributes :attr1
      end
    end

    let(:associated_object) do
      Class.new(ActiveRecordMock) do
        attr_reader :attr1

        def initialize(attribute_value)
          @attr1 = attribute_value
        end
      end
    end

    let(:main_object) do
      Class.new(Tint::Decorator) do
        attr_reader :associated

        def initialize(associated)
          @associated = associated
        end
      end
    end

    let(:object) { main_object.new(associated_object.new('value')) }

    context "when no with option is provided" do
      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          decorates_association :associated
        end
      end

      before(:each) do
        Object.const_set('AssociatedDecorator', associated_decorator)
      end

      it "attempts to use a decorator with the same name as the association" do
        expect(subject['associated']['attr1']).to eql('value')
      end

      after(:each) do
        Object.send(:remove_const, 'AssociatedDecorator')
      end
    end

    context "when a with option is provided" do
      let(:explicitly_referenced_decorator) do
        Class.new(Tint::Decorator) do
          attributes decorated1: :attr1
        end
      end

      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          decorates_association :associated, with: ExplicitlyReferencedDecorator
        end
      end

      before(:each) do
        Object.const_set('ExplicitlyReferencedDecorator', explicitly_referenced_decorator)
      end

      it "uses the specified decorator" do
        expect(subject['associated']['decorated1']).to eql('value')
      end

      after(:each) do
        Object.send(:remove_const, 'ExplicitlyReferencedDecorator')
      end
    end
  end

  describe "::eager_load" do
    it "adds the associations to the list to eager load" do

      eager_load_schemas = [
          [:associated],
          [ { associated1: [:associated2] } ],
          [ { associated1: { associated2: [:associated3] } } ],
          [ :associated1, { associated2: [:associated3] } ]
      ]

      eager_load_schemas.each do |eager_load_schema|
        decorator_class =
            Class.new(Tint::Decorator) do
              eager_load *eager_load_schema
            end

        eager_load_schema.each do |schema|
          expect(decorator_class.eager_loads).to include(schema)
        end
      end
    end
  end
end
