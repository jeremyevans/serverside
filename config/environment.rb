require 'rubygems'
require 'active_record'
require 'active_support/inflector'

$config = {}

ENV['ENVIRONMENT'] ||= ($config[:mode] || :development).to_s
ENVIRONMENT = ENV['ENVIRONMENT'].to_sym

DB_CONNECTIONS = {
}

require 'config/config'
#require 'lib/extensions'
#require 'lib/errors'
#require 'lib/logging'
#require 'lib/controllers'
#require 'lib/models'
#require 'lib/views'

if DB_CONNECTIONS[ENVIRONMENT]
  ActiveRecord::Base.establish_connection(DB_CONNECTIONS[ENVIRONMENT])
end