# frozen_string_literal: true

require './lib/logs'

logs '=====> Bootstrapping'
require 'bundler'
Bundler.require :default, (ENV['RACK_ENV'] || 'production').to_sym

logs '=====> Loading framework'
require './lib/rogare'

logs '=====> Preparing resources'
DB = Rogare.sql
Rogare::Data.goal_parser_impl
Sequel::Model.plugin :eager_each
Sequel::Model.plugin :pg_auto_constraint_validations
Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :prepared_statements_safe

logs '=====> Loading models'
Dir['./models/*.rb'].each do |p|
  logs "     > #{Pathname.new(p).basename('.rb').to_s.camelize}"
  require p
end
