add_source "http://gems.rubyforge.org/"

add_gem 'mongrel'
add_gem 'sinatra'
add_gem 'oauth'
add_gem 'rest-client'

add_dependency 'do_sqlite3', '=0.9.9'

add_dependency 'extlib', '=0.9.9', :require => 'extlib'
add_dependency 'dm-core', '=0.9.8', :require => 'dm-core'
add_dependency 'dm-validations', '=0.9.8', :require => 'dm-validations'
