require 'rubygems'

$config = {}

ENV['ENVIRONMENT'] ||= ($config[:mode] || :development).to_s
ENVIRONMENT = ENV['ENVIRONMENT'].to_sym

DB_CONNECTIONS = {
}

require 'config/config'
require_all 'lib/extensions'
#require 'lib/errors'
#require 'lib/logging'
require_all 'lib/controller'
#require 'lib/models'
#require 'lib/views'

if DB_CONNECTIONS[ENVIRONMENT]
  require 'active_record'
  require 'active_support/inflector'
  ActiveRecord::Base.establish_connection(DB_CONNECTIONS[ENVIRONMENT])
end
