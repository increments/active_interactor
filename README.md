# ActiveInteractor

[![Gem](https://img.shields.io/gem/v/active_interactor.svg)](https://rubygems.org/gems/active_interactor)
[![Build Status](https://travis-ci.org/increments/active_interactor.svg?branch=master)](https://travis-ci.org/increments/active_interactor)
[![Code Climate](https://codeclimate.com/github/increments/active_interactor/badges/gpa.svg)](https://codeclimate.com/github/increments/active_interactor)
[![Test Coverage](https://codeclimate.com/github/increments/active_interactor/badges/coverage.svg)](https://codeclimate.com/github/increments/active_interactor/coverage)
[![license](https://img.shields.io/github/license/increments/active_interactor.svg)](https://github.com/increments/active_interactor/blob/master/LICENSE)

Simple use case interactor for Rails apps based on ActiveModel.

It is heavily inspired by [Hanami::Interactor](http://hanamirb.org/guides/1.2/architecture/interactors/).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_interactor'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_interactor

## Usage

Include `ActiveInteractor` into a class to define your interactor. It must implement `#call` method
and may declare which instance variables to be exposed:

```rb
class CreateProduct
  include ActiveInteractor

  expose :product

  def initialize(repository: ProductRepository)
    @repository = repository
  end

  def call(attributes)
    @product = @repository.create(attributes)
  end
end
```

Calling an interactor instance returns a `ActiveInteractor::Result`. It has success or failure state:

```rb
result = CreateProduct.new.call(params)
result.is_a? ActiveInteractor::Result #=> true
result.success? # `true` or `false`. In this case `true`
result.failure? # opposite of #success?
```

It responds to the exposed messages above:

```rb
result.product #=> The object returned by `@repository.create`
result.repository #=> NeMethodError
```

You may use the interactor in your controllers:

```rb
class ProductsController < ApplicationController
  def create
    result = CreateProduct.new.call(product_params)
    if result.success?
      redirect_to result.product
    else
      @errors = result.errors
      render :edit
    end
  end

  private

  def product_params
    params.require(:product).permit(:name)
  end
end
```

### Failure

Adding a message to `#errors` causes failure result.

```rb
def call(*)
  errors.add(:base, 'fail')
end
```

```rb
result = FailureInteractor.new.call

result.success? #=> false
result.errors.full_messages_for(:base) #=> ['fail']
```

You can use `#merge_errors` utility to merge another `ActiveModel::Errors` into `#errors`:

```rb
def call(params)
  @product = @repository.create(params)
  # Return failure result if @product is invalid
  merge_errors(@product.errors) if @product.invalid?
end
```

### Validation

```rb
class CreateProduct
  include ActiveInteractor

  # Declare all key names
  validations(:name) do
    # Write your validation rules with Rails DSL    
    validates :name, presence: true
  end

  call(params)
    # You can assume `params` pass the validations described above.
    # If some validation fails, this method isn't invoked.
  end
end
```

```rb
result = CreateProduct.new.call(name: nil)
result.success? #=> false
result.errors.full_messages_for(:name) #=> ["name can't be blank"]
```

Validator can access interactor instance via `#interactor`:

```rb
class FollowUser
  include ActiveInteractor

  validations(:target_user) do
    validates :target_user, presence: true
    validate :user_must_not_follow_target_user

    def user_must_not_follow_target_user
      errors.add(:target_user, :already_following) if interactor.user.follow?(target_user)
    end
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call(target_user:)
    user.follow(target_user)
  end
end
```

### I18n

```yaml
ja:
  activeinteractor:
    models:
      create_product: :activerecord:models:product
    attributes:
      create_product: :activerecord:attributes:product
    errors:
      models:
        create_product:
          attributes:
            name:
              blank: を入力してください
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/increments/active_interactor. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveInteractor project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/increments/active_interactor/blob/master/CODE_OF_CONDUCT.md).
