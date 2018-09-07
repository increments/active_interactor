require 'active_support'
require 'active_model'

require 'active_interactor/version'

# ActiveInteractor.
#
# @example
#   class CreateProduct
#     include ActiveInteractor
#
#     expose :product
#
#     validations(:name, :price) do
#       validates :name, presence: true, length: { maximum: 50 }
#       validates :price, presence: true, numericality: { only_integer: true }
#     end
#
#     def initialize(repository)
#       @repository = repository
#     end
#
#     def call(attributes)
#       @product = @repository.create(attributes)
#     end
#   end
module ActiveInteractor
  extend ActiveSupport::Concern

  class_methods do
    # Configure {.validator_class}
    #
    # @param attribute_names [Array<Symbol>] list of
    # @yield
    # @return [void]
    def validations(*attribute_names, &block)
      @validation_attribute_names = attribute_names
      validator_class.class_eval do
        attr_accessor(*attribute_names)
      end
      validator_class.class_eval(&block)
    end

    # @return [Class]
    def validator_class
      @validator_class ||= build_validator_class
    end

    # Expose local instance variables into the returning value of {#call}
    #
    # @param instance_variable_names [Array<Symbol>]
    def expose(*instance_variable_names)
      instance_variable_names.each do |name|
        exposures[name.to_sym] = "@#{name}"
      end
    end

    # @return [Hash]
    def exposures
      @exposures ||= {}
    end

    # @return [Array<Symbol>]
    def validation_attribute_names
      @validation_attribute_names || []
    end

    # @return [Boolean]
    def validation_required?
      validation_attribute_names.present?
    end

    private

    # @return [Class]
    def build_validator_class
      klass = Class.new do
        include ActiveModel::AttributeAssignment
        include ActiveModel::Validations
        extend ActiveModel::Translation

        # @note {ActiveModel::Translation} expects anonymous class to implement {.name}
        cattr_accessor :name

        # @note Override {ActiveModel::Translation::ClassMethods#i18n_scope}
        def self.i18n_scope
          :activeinteractor
        end

        # @param [ActiveInteractor]
        def initialize(interactor)
          @__interactor = interactor
        end

        # @return [ActiveInteractor]
        # @note This method will be overridden if it is declared to validate :interactor attribute.
        def interactor
          @__interactor
        end
        alias_method :__interactor, :interactor
      end
      klass.name = name || 'ActiveInteractor' # Fallback for anonymous classes
      klass
    end
  end

  included do
    prepend ActiveInteractor::Interface
    attr_reader :errors
  end

  # Interactor interface.
  module Interface
    # rubocop:disable all

    # @param args [Array<(nil)>, Array<(Hash)>]
    # @return [ActiveInteractor::Result]
    def call(*args)
      raise ArgumentError if args.size > 1
      raise ArgumentError if args.size == 1 && !args.first.is_a?(Hash)

      params = args.extract_options!

      if params.empty? && !self.class.validation_required?
        @errors = validator.errors
        super
      else
        params = sanitize(params)
        @errors = validate(params)
        super(params) if @errors.empty?
      end

      Result.new(result_payload, @errors)
    end

    # rubocop:enable all
  end

  # Result of an operation.
  class Result
    # @return [ActiveModel::Errors]
    attr_reader :errors

    # Concrete methods
    #
    # @see ActiveInteractor::Result#respond_to_missing?
    METHODS = Set.new(%i[initialize success? failure?])

    # @param payload [Hash]
    # @param errors [ActiveModel::Errors]
    def initialize(payload, errors)
      @payload = payload.symbolize_keys
      @errors = errors
    end

    # @return [Boolean]
    def success?
      !failure?
    end

    # @return [Boolean]
    def failure?
      errors.present?
    end

    private

    def method_missing(method_name, *)
      @payload.fetch(method_name) { super }
    end

    def respond_to_missing?(method_name, _include_all)
      method_name = method_name.to_sym
      METHODS.include?(method_name) || @payload.key?(method_name)
    end
  end

  def call(*)
    raise NotImplementedError
  end

  # Merge the given errors into {#errors}.
  #
  # @param additional_errors [ActiveModel::Errors]
  # @return [void]
  def merge_errors(additional_errors)
    additional_errors.full_messages.each do |message|
      errors.add(:base, message)
    end
  end

  def validator
    @validator ||= self.class.validator_class.new(self)
  end

  private # rubocop:disable Lint/UselessAccessModifier

  # @return [Hash] a hash representing a payload for {ActiveInteractor::Result}
  def result_payload
    Hash[].tap do |result|
      self.class.exposures.each do |name, ivar|
        result[name] = instance_variable_defined?(ivar) ? instance_variable_get(ivar) : nil
      end
    end
  end

  # @param args [Hash]
  # @return [ActiveModel::Errors]
  def validate(params)
    if self.class.validation_required?
      validator.assign_attributes(params)
      validator.valid?
    end
    validator.errors
  end

  # Remove undeclared keys from the given params.
  #
  # @param params [Hash]
  # @return [Hash]
  def sanitize(params)
    return params unless self.class.validation_required?
    Hash[].tap do |result|
      self.class.validation_attribute_names.each do |name|
        result[name] = params[name]
      end
    end
  end
end
