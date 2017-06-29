# encoding: UTF-8
require 'rubygems'
require 'sinatra'
require 'active_record'
require 'yaml'
require 'resolv'
require 'dotenv/load'
require 'erb'

DOMAIN_REGEX = /(^$)|(^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$)/ix
IPV4_REGEX   = /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/
DEBUG        = false

YAML::load(File.open('config/database.yml'))['production'].symbolize_keys.each do |key, value|
  renderer = ERB.new(value)
  set key, renderer.result()
end

configure do
  # http://recipes.sinatrarb.com/p/middleware/rack_commonlogger
  file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  file.sync = true
  use Rack::CommonLogger, file
end

ActiveRecord::Base.establish_connection(
  adapter:  settings.adapter,
  host:     settings.host,
  database: settings.database,
  username: settings.username,
  password: settings.password
)

class Domain < ActiveRecord::Base
  self.inheritance_column = :___disabled
end
class Record < ActiveRecord::Base
  self.inheritance_column = :___disabled
end

class String
  def blank?
    self == nil || self == ''
  end
end

# action should be block or release
get '/:action/:ip_or_host' do
  begin
    ActiveRecord::Base.clear_active_connections!
    # get params
    ip_or_host = params[:ip_or_host]
    action = params[:action]
    # halt if param blank
    halt 403 if ip_or_host.blank?
    halt 403 if action.blank? || !['block', 'release'].include?(action)
    # get the ip-address
    ip = if ip_or_host.match(DOMAIN_REGEX)
      # domain
      a = Resolv::DNS.open do |dns|
        dns.getresources(ip_or_host, Resolv::DNS::Resource::IN::A)
      end
      # extract ip or return nil
      a == nil || a == [] ? nil : (a.map(&:address))[0].to_s
    elsif ip_or_host.match(IPV4_REGEX)
      # ip
      ip_or_host
    else
      nil
    end
    # skip if ip not valid
    if ip == nil
      puts "ip not found: #{ip}" if DEBUG
      halt 403
    end
    # get domain record
    d = Domain.find_by(name: ENV['DOMAIN'])
    if d == nil
      puts "Domain not found: #{ENV['DOMAIN']}" if DEBUG
      halt 404
    end
    # get reverse ip
    ptr = ip.split(".").reverse.join(".")
    ptr_fqdn = "#{ptr}.#{d.name}"
    # any records present?
    r = Record.where(name: ptr_fqdn)
    # process actions
    if action == 'block'
      # block ip
      if r.blank?
        puts "block ip: #{ip}" if DEBUG
        # create A and TXT records
        Record.create(
          domain_id:   d.id,
          name:        ptr_fqdn,
          type:        "A",
          content:     "127.0.0.2",
          ttl:         0,
          change_date: Time.now.to_i
        )
        Record.create(
          domain_id:   d.id,
          name:        ptr_fqdn,
          type:        "TXT",
          content:     "#{ENV['TXT_INFO']}#{ip}",
          ttl:         0,
          change_date: Time.now.to_i
        )
      else
        puts "ip already blocked: #{ip}" if DEBUG
      end
    else
      # release ip
      puts "release ip: #{ip}" if DEBUG
      if r.any?
        # delete A and TXT records
        r.each { |record| record.destroy }
      else
        # error: no record to delete
        puts "no records to delete for ip: #{ip}" if DEBUG
        halt 404
      end
    end
    # all done
    status 200
  rescue Exception => e
    logger.warn "[dnsbl#block] Rescue: #{e.message}"
    halt 400
  end
end

get "/*" do
  halt 403
end