# Tint

Easily define object decorators for JSON APIs using simple declarative syntax 

## Installation

Add this line to your application's Gemfile:

    gem 'tint'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tint

## Usage

You can use Tint by creating a decorator class that inherits from `Tint::Decorator`

## Defining attributes

To include methods and attributes available on the decorated object, simply list them using `attributes`. 

```ruby
# decorators/user_decorator.rb
class UserDecorator < Tint::Decorator
  attributes :username, :first_name, :last_name 
end
```

You can map attributes to different names on the decorator by providing a hash as the final argument 
 
```ruby
# decorators/user_decorator.rb
class UserDecorator < Tint::Decorator
  attributes :username, :first_name, last_name: :surname # object.surname will be available as ['last_name']
end
```

## Defining custom methods

Tint will use a decorator instance method in preference to one defined on the decorated object, so it is possible to customise how a particular attribute appears. The original definition of the attribute is available via the `object` instance variable.

```ruby
class ProductDecorator < Tint::Decorator
  attributes :id, :description, :price
  
  def price
    "$" + object.price  
  end
end
```

It's also possible to define methods that are not available on the decorated object at all.

```ruby
class ProductDecorator < Tint::Decorator
  attributes :id, :description, :on_sale
  
  def on_sale
    SaleItems.include?(object)  
  end
end
```

## Defining associations

The `decorates_association` method is used for declaring associations and delegating them to other decorators.

```ruby
# decorators/product_decorator.rb
class ProductDecorator < Tint::Decorator
  attributes :id, :description
end

# decorators/user_decorator.rb
class UserDecorator < Tint::Decorator
  attributes :username
  
  decorates_association :products
end
```

By default, `decorates_association` uses the name of the association to guess the decorator it should use. In this case it will use `ProductDecorator`, but if you wished to render with `SpecialProductDecorator`, the `with` option may be used:
 
```ruby
decorates_association :product, with: SpecialProductDecorator
```

You can decorate an association and make it available under a different name using the `as` option:

```ruby
decorates_association :product, as: :sale_item
```

Multiple associations can be defined in the same statement using `decorates_associations`. Either, using interpolation to locate the correct decorator for each:

```ruby
decorates_associations :product, :address
```

Or using the same decorator (in this case, `AddressDecorator`):

```ruby
decorates_associations :previous_address, :current_address, with: AddressDecorator
```

## Eager loading associations

When you declare a new association using `decorates_association` or `decorates_associations`, Tint automatically eager loads the associations when the decorator is rendered as JSON and automatically prevents many N+1 queries. It does this by maintaining a list `eager_loads` which is available on all decorators.
 
```ruby
class UserDecorator < Tint::Decorator
  attributes :username
  
  decorates_association :products
end
 
 
UserDecorator.eager_loads # [:products]
```

If you need to manually add to the list of associations which are eager loaded for any reason, you can do so using the `eager_load` method
 
```ruby
class UserDecorator < Tint::Decorator
  attributes :username
  
  decorates_association :products
  
  eager_load :addresses
end

UserDecorator.eager_loads # [:products, :addresses]
```

## Decorating a single instance

Tint maintains the interface defined by Draper for decorating objects. To decorate a single object, use the `decorate` method. 

Using the `UserDecorator` defined above:

```ruby
# controllers/users_controller.rb

class UsersController < ApplicationController

  def show
    @user = User.find(params[:id]) #<User username: "john_doe", first_name: "John", surname: "Doe">
     
    render json: UserDecorator.decorate(@user) # { username: "john_doe", firstName: "John", lastName: "Doe" }
  end
  
end
```

`decorate` also accepts an optional has of options. For more information about the supported options, see the [Draper documentation](https://github.com/drapergem/draper#adding-context).
 
 
## Decorating a collection

The `decorate_collection` method is used for decorating an instance of ActiveRecord::Relation (or any class that implements the same interface). It accepts all of the same options as the `decorate` method.

```ruby
# controllers/users_controller.rb

class UsersController < ApplicationController

  def index
    @users = User.all
     
    render json: UserDecorator.decorate_collection(@users) # [ { username: "john_doe", firstName: "John", lastName: "Doe" }, ... ]
  end
  
end
```
    
## Configuration

By default, Tint camelizes attribute names, however it's possible to configure Tint to use any of the following capitalization conventions:
  
```ruby
Tint.configuration do |config|
  # attribute_naMe123 ==> attributeNaMe123 (Default)
  # config.attribute_capitalization = :camel_case

  # attribute_naMe123 ==> attribute_na_me123
  # config.attribute_capitalization = :snake_case

  # attribute_naMe123 ==> attribute-naMe123
  # config.attribute_capitalization = :kebab_case

  # Converts symbols to strings
  # config.attribute_capitalization = :none
end
```

## Running the test suite

The test suite may be run simply using

    rspec

## Contributions

Tint remains in its infancy and all pull requests, issues and feedback are welcome and appreciated.

