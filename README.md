# Confix

Adds well-defined configuration options to any class. This gem is similar to Mark Bates' Configuratron, except that it takes a well-defined configuration structure as a basis. By providing inline documentation, the settings can easily be documented, allowing for better to understand configuration.

Confix adds support for loading configuration from a Hash (or YAML file), and provides templating to DRY up the configuration structure.

## Installation

Add this line to your application's Gemfile:

    gem 'confix'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install confix

## Usage

Include this module in a new object, like so:

    class MyConfiguration
      include Confix

      setting :database_url

      config :external_api do
        setting :enabled, false
        setting :client_id
        setting :client_secret
      end
    end

Now, one can access these properties like this:

    cfg = MyConfiguration.new

    cfg.database_url = 'http://www.database.com'
    cfg.external_api.client_id = 'MyApp'

or

    cfg.external_api.update :client_id => 'MyApp', :client_secret => '1234567890'

Method `setting` allows you to define a single setting, and method `config` allows you to define a sub-configuration.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request