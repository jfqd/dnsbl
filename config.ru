# encoding: UTF-8
require 'rubygems'
require 'bundler/setup'
require "#{File.dirname(__FILE__)}/app"

set :run, false

run Sinatra::Application