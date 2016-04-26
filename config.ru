require 'bundler'
Bundler.require
require './app'
require './backend'
use Websockettest2::Backend
run Sinatra::Application
