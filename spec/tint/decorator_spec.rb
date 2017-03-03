require 'tint'
require_relative '../support/active_record_mock'

require 'spec_helper'

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

  context "when not attributes have been set" do
    let(:decorator_class) do
      Class.new(Tint::Decorator) do

      end
    end

    it "returns an empty object" do
      expect(subject).to eql({})
    end
  end

  describe "::attributes" do
    context "when an broken reference is used" do
      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          attributes :broken_reference
        end
      end

      it "does not include it in the object" do
        expect(subject).to eql({})
      end
    end

    context "when only delegations are defined" do
      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          attributes :attr1
        end
      end

      it "delegates attributes of the same name to the object" do
        expect(subject['attr1']).to eql('one')
      end

      it "does not include any attributes not mentioned" do
        expect(subject['attr2']).to be_nil
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

    context "when a :with option is provided" do
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

    context "when a :as option is provided" do

      let(:associated_decorator) do
        Class.new(Tint::Decorator) do
          attributes :attr1
        end
      end

      let(:decorator_class) do
        Class.new(Tint::Decorator) do
          decorates_association :associated, as: 'related'
        end
      end

      before(:each) do
        Object.const_set('AssociatedDecorator', associated_decorator)
      end

      it "uses the specified decorator" do
        expect(subject['related']['attr1']).to eql('value')
      end

      after(:each) do
        Object.send(:remove_const, 'AssociatedDecorator')
      end
    end
  end

  describe "::eager_load" do
    it "adds the associations to the list to eager load" do

      eager_load_schemas = [
          [:associated],
          [ { associated1: { associated2: {} } } ],
          [ { associated1: { associated2: { associated3: {} } } } ],
          [ :associated1, { associated2: { associated3: {} } } ]
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

  describe "::parent_eager_loads_include_own?" do
    let(:decorator_class) do
      Class.new(Tint::Decorator) do
        eager_load :products
      end
    end

    before(:each) do
      Object.const_set('AssociatedDecorator', decorator_class)
    end

    context "when the decorator has no parent" do
      let(:parent_decorator_class) { nil }

      it "returns false" do
        expect(decorator_class.parent_eager_loads_include_own?).to eql(false)
      end
    end

    context "when the decorator has a parent set via decorates_association" do
      let(:parent_decorator_class) do
        Class.new(Tint::Decorator) do
          decorates_association :associated
        end
      end

      it "returns true" do
        context = {
            parent_decorator: parent_decorator_class.decorate(object_class),
            parent_association: [:associated]
        }

        expect(decorator_class.parent_eager_loads_include_own?(context)).to eql(true)
      end
    end

    context "when a decorator has a parent manually set" do
      context "and the parent doesn't manually eager load the association" do
        let(:parent_decorator_class) do
          Class.new(Tint::Decorator) do
            attributes :associated

            def associated
              AssociatedDecorator.decorate(object, context: {
                  parent_decorator: self,
                  parent_association: [:associated]
              })
            end

          end

        end

        it "returns false" do
          decorated_class = parent_decorator_class.decorate(object_class.new('foo', 'bar'))

          context = decorated_class.send(:associated).context
          expect(decorator_class.parent_eager_loads_include_own?(context)).to eql(false)
        end
      end

      context "and the parent manually loads the eager association" do
        let(:parent_decorator_class) do
          Class.new(Tint::Decorator) do
            attributes :associated

            eager_load :associated

            def associated
              AssociatedDecorator.decorate(object.attr1, context: {
                  parent_decorator: self,
                  parent_association: [:associated]
              })
            end

          end

        end

        it "returns true" do
          associated_object = object_class.new('foo', 'bar')

          decorated_class = parent_decorator_class.decorate(
              object_class.new(associated_object, 'bar')
          )

          context = decorated_class.associated.context

          expect(decorator_class.parent_eager_loads_include_own?(context)).to eql(true)
        end
      end
    end

    after(:each) do
      Object.send(:remove_const, 'AssociatedDecorator')
    end
  end


end
