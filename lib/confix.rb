# This module makes it easy for any configuration object to define itself declaratively.
#
# === Usage
#
# Include this module in a new object, like this:
#
#   class MyConfiguration
#     include Confix
#
#      setting :database_url
#      config :external_api do
#        setting :client_id
#        setting :client_secret
#      end
#
#   end
#
# Now, one can access these properties like this:
#
#   cfg = MyConfiguration.new
#
#   cfg.database_url = 'http://www.database.com'
#   cfg.external_api.client_id = 'MyApp'
#
# or
#
#  cfg.external_api.update :client_id => 'MyApp', :client_secret => '1234567890'
#
# One can access the settings using indexers or method calls, just like in OpenStruct. Also,
# symbols or strings can be used by the indexers, mimicking HashWithIndifferentAccess. One
# can even get or set a property of a child configuration easily:
#
#   raise 'invalid secret' if cfg['external_api.client_secret'] != secret
#
# === Notes
#
# Internally, all settings are stored in the 'root' configuration object. Imagine you have the
# following configuration setup:
#
#   class Configuration
#     include Confix
#
#     config :child1 do
#       setting :one
#     end
#     config :child2 do
#       setting :two
#       config :child2a do setting :three end
#     end
#   end
#
# Configurations +child1+ and +child2+ will not store their own configuration values. Instead,
# all configuration options are stored in the root object, using the following keys:
# * +child1.one+
# * +child2.two+
# * +child2.child2a.three
#
# This allows for rapid lookup and exporting. Any operation on a child configuration will forward
# their call to the root object.
#
# Convenience accessors are created to retrieve values. Using the example above, one can access
# the same setting in the following ways:
#
#   config = Configuration.new
#
#   config.child1.one = 'One'
#   config.child2[:two] = 'Two'
#   config['child2.child2a.three'] = 'Three'
#
#   config[:child1].one          # => 'One'
#   config.child2[:one]          # raises {UndefinedSetting}
#   config.child2.child2a.three  # => 'Three'
#
# If you use an intermediate key, you will get a Config object.
#
#   config.child2                # #<Confix::Config @parent=#<Configuration>>
#   config.child2 = 'something'  # (raises {CannotModifyConfiguration})
#
# == Assigns
#
# You may add assignment variables to the {#assigns} hash. This hash is used to interpolate
# string settings.
#
# === Example
#
#   config.assigns[:some_path] = '/path/to/something'
#   config.path_setting = '%{some_path}/file.yml'
#   config.path_setting # => '/path/to/something/file.yml'
module Confix

  def self.included(base)
    base.send :include, InstanceMethods
    base.send :extend, ClassMethods

    base.send :include, RootInstanceMethods
    base.send :extend, RootClassMethods
  end

  # This exception is raised when an undefined setting was being accessed.
  class UndefinedSetting < RuntimeError; end
  class CannotModifyConfiguration < RuntimeError; end

  ######
  # Root instance methods

    module RootInstanceMethods

      # @!attribute [r] assigns
      # @return [Hash]
      #   Assignment variables. These are available as interpolation arguments in any string
      #   setting. You can modify this hash.
      def assigns
        @assigns ||= {}
      end

      # Determines whether this configuration is a child configuration.
      def child?
        false
      end

      def fetch(name, default)
        value = values[name]
        value = default if value.nil?
        value = value % assigns if value.is_a?(String)
        value
      end

      # Gets the config root (this object).
      def config_root
        self
      end

      # Gets all configuration values.
      def values
        @values ||= {}
      end

      # Gets a hash containing intermediate configuration objects.
      def configs
        @configs ||= {}
      end

    end

  ######
  # Root class methods

    module RootClassMethods

      # Defines a reusable configuration template. If you specify a configuration you may refer to this template
      # rather than specifying a block.
      def template(name, &block)
        raise ArgumentError, "block required" unless block
        templates[name.to_s] = block
      end

      def templates
        @templates ||= {}
      end

    end

  module InstanceMethods

    def self.included(target)
      # Delegate common hash functions to the hash.
      [ :each, :map, :select, :except, :symbolize_keys ].each do |method|
        target.class_eval <<-RUBY, __FILE__, __LINE__+1
          def #{method}(*args, &block)
            to_hash.#{method} *args, &block
          end
        RUBY
      end
    end

    ######
    # Indexers

      # Gets a setting by the given key.
      #
      # If the key refers to a child configuration, it retrieves an intermediate object
      # that can be used for easy acess. See the examples in {Confix}.
      #
      # If the key refers to an existing setting, its value is returned. If the value
      # was not found or was nil, the given default value is returned.
      #
      # If the value was not found, and no default was specified here, a default value
      # for the setting is tried.
      def get(key, default = nil)
        key = key.to_s

        default = self.class.defaults[key] if default.nil?

        if self.class.configs[key]
          # If the key refers to a child configuration class, instantiate this.
          config_root.configs[self.class.expand_key(key)] ||= self.class.configs[key].new(self)
        elsif child?
          raise UndefinedSetting, "setting '#{self.class.expand_key(key)}' does not exist" unless self.class.key_defined?(key)

          # Ask the config_root object for the value.
          config_root.fetch(self.class.expand_key(key), default)
        else
          raise UndefinedSetting, "setting '#{self.class.expand_key(key)}' does not exist" unless self.class.key_defined?(key)

          fetch(key, default)
        end
      end

      # Sets a setting by the given key.
      #
      # If the key refers to a child configuration, an exception is returned.
      def set(key, *value)
        if value.length == 0 && key.is_a?(Hash)
          # Apply the hash to the settings.
          key.each { |key, value| set key, value }
        else
          raise ArgumentError, 'too many arguments (1 or 2 expected)' if value.length > 1
          value = value.first

          key = key.to_s

          if self.class.configs[key]
            raise CannotModifyConfiguration, "you cannot set option #{key} as it refers to a child configuration"
          elsif child?
            raise UndefinedSetting, "setting '#{self.class.expand_key(key)}' does not exist" unless self.class.key_defined?(key)
            config_root.values[self.class.expand_key(key)] = value
          else
            raise UndefinedSetting, "setting '#{self.class.expand_key(key)}' does not exist" unless self.class.key_defined?(key)
            values[key] = value
          end
        end
      end

      # Gets all current configuration values.
      def to_hash
        values = {}
        self.class.settings.each do |key|
          values[key] = get(key)
        end
        self.class.configs.each do |key, config|
          values[key] = get(key).to_hash
        end
        values
      end

      # (Recursively) updates this configuration from a hash.
      def update(hash)

        if hash
          hash.each do |key, value|
            if value.is_a?(Hash)
              self[key].update value
            else
              self[key] = value
            end
          end
        end

        self
      end

      alias :[] :get
      alias :[]= :set

    ######
    # Method missing

      private

      def method_missing(method, *args, &block)
        raise UndefinedSetting, "setting '#{self.class.expand_key(method)}' does not exist"
      end

  end

  module ClassMethods

    ######
    # DSL

      # Defines a setting for this configuration. If this configuration was defined as a child
      # of some parent configuration, this parent configuration will also create a definition
      # for this setting, but no accessor methods.
      #
      # @param [Object] default  Specify a default value for the setting.
      def setting(key, default = nil)
        key = key.to_s
        raise ArgumentError, "invalid key: #{key}" unless Confix.valid_key?(key)

        settings << key
        defaults[key] = default if default
        define_accessor_methods key
      end

      # Defines a child configuration for this configuration.
      def config(key, template = nil, &block)
        key = key.to_s
        raise ArgumentError, "invalid key: #{key}" unless Confix.valid_key?(key)

        config = Class.new(Config)
        config.instance_variable_set '@parent', self
        config.instance_variable_set '@key_from_root', expand_key(key)

        # If no template or block are specified, infer a default template from the name.
        if !template && !block
          template = key
          raise ArgumentError, "no template or block specified, and no template :#{key} found" unless config_root.templates[template]
        elsif template
          template = template.to_s
          raise ArgumentError, "template :#{key} not found" unless config_root.templates[template]
        end

        # If a template is specified, first apply its block.
        config.class_eval &config_root.templates[template] if template

        # Apply the block.
        config.class_eval &block if block

        # Wrap up.
        define_accessor_methods key
        configs[key] = config
        config
      end

    ######
    # Attributes

      def settings
        @settings ||= []
      end
      def defaults
        @defaults ||= {}
      end
      def configs
        @configs ||= {}
      end

      def config_root
        @parent ? @parent.config_root : self
      end

      attr_reader :key_from_root

    ######
    # Support

      def expand_key(key)
        [ @key_from_root, key ].compact.join('.')
      end

      def key_defined?(key)
        if key.is_a?(Array)
          tail = key
        else
          tail = key.to_s.split('.')
        end

        head = tail.shift
        if configs.keys.include?(head)
          configs[head].key_defined?(tail)
        elsif settings.include?(head) && tail.empty?
          true
        else
          false
        end
      end

    private

      def define_accessor_methods(key)
        class_eval <<-RUBY, __FILE__, __LINE__+1
          def #{key}; get(:#{key}) end
          def #{key}=(value) set(:#{key}, value) end
        RUBY
      end

  end

  ######
  # Child Config object.

    # A simple Config object, which is created if people access a intermediate
    # setting.
    class Config
      def initialize(parent = nil)
        @parent = parent
      end

      # Resolves the root configuration object.
      def config_root
        @config_root ||= @parent ? @parent.config_root : self
      end
      def child?
        true
      end

      include Confix::InstanceMethods
      extend Confix::ClassMethods

      def self.name
        "Confix::Config(#{key_from_root})"
      end

      def inspect
        super.sub(/#<Class:0x[a-f0-9]+>/, "#<#{self.class.name}>")
      end
    end

  def self.valid_key?(key)
    key.to_s !~ /[^_a-zA_Z0-9]/
  end

end