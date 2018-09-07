RSpec.describe ActiveInteractor do
  describe 'interactor with validations' do
    subject { interactor.call(*params) }

    let(:interactor_class) do
      Class.new do
        include ActiveInteractor

        expose :product

        validations(:name, :price) do
          validates :name, presence: true, length: { maximum: 50 }
          validates :price, presence: true, numericality: { only_integer: true }
        end

        def initialize(repository)
          @repository = repository
        end

        def call(attributes)
          @product = @repository.create(attributes)
        end
      end
    end

    let(:interactor) { interactor_class.new(repository) }
    let(:repository) { double('ProductRepository', create: created_product) }
    let(:created_product) { Object.new }

    context 'with valid params' do
      let(:params) { [{ name: 'Qiitan', price: 100 }] }

      it 'returns a successful result with exposing the product' do
        is_expected.to be_success.and have_attributes(product: created_product)
      end
    end

    context 'with malicious param' do
      let(:params) { [{ name: 'Qiitan', price: 100, malicious: 'param' }] }

      it "doesn't pass through the malicious param to a repository" do
        expect(subject).to be_success
        expect(repository).to have_received(:create).with(name: 'Qiitan', price: 100)
      end
    end

    context 'with invalid params' do
      let(:params) { [{ name: 'Product without price' }] }

      it 'returns a failure result with errors' do
        is_expected.to be_failure.and have_attributes(
          errors: an_object_having_attributes(
            full_messages: match_array(["Price can't be blank", 'Price is not a number'])
          )
        )
      end
    end

    context 'with non-hash params' do
      let(:params) { ['string parameter'] }
      it { expect { subject }.to raise_error(ArgumentError) }
    end

    context 'with two hash params' do
      let(:params) { [{ name: 'Qiitan' }, { price: 100 }] }
      it { expect { subject }.to raise_error(ArgumentError) }
    end
  end

  example 'without validations' do
    interactor_class = Class.new do
      include ActiveInteractor

      expose :product

      def call(value:)
        @product = value * 2
      end
    end

    result = interactor_class.new.call(value: 10)
    expect(result).to be_success.and(have_attributes(product: 20))
  end

  example 'fail while calling' do
    interactor_class = Class.new do
      include ActiveInteractor

      expose :product

      def call
        errors.add(:base, :invalid)
      end
    end

    result = interactor_class.new.call
    expect(result).to be_failure.and(have_attributes(product: nil))
  end

  example 'using #merge_errors' do
    interactor_class = Class.new do
      include ActiveInteractor

      def initialize(errors)
        @additional_errors = errors
      end

      def call
        merge_errors(@additional_errors)
      end
    end

    result = interactor_class.new(instance_double('ActiveModel::Errors', full_messages: ['custom error message'])).call
    expect(result).to be_failure
    expect(result.errors.full_messages).to eq ['custom error message']
  end

  example 'accessing interactor from validator' do
    interactor_class = Class.new do
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

    user = double('User')
    allow(user).to receive(:follow?).and_return(true)
    allow(user).to receive(:follow)
    target_user = double('User')
    result = interactor_class.new(user).call(target_user: target_user)
    expect(result).to be_failure
    expect(user).to have_received(:follow?).with(target_user).once
    expect(user).not_to have_received(:follow)
  end
end
