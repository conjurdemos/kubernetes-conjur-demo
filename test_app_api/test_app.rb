#!/usr/bin/env ruby

require 'sinatra'
require 'conjur-api'
require 'cgi'
require 'json'

enable :logging

helpers do
  def username
    raise "Expecting CONJUR_AUTHN_API_KEY to be blank" if ENV['CONJUR_AUTHN_API_KEY']
    ENV['CONJUR_AUTHN_LOGIN'] or raise "No CONJUR_AUTHN_LOGIN"
  end
  
  def conjur_api
    # Ideally this would be done only once, but if a login fails during testing
    # the pod ends up stuck in a bad state and the tests can't be performed.
    Conjur.configuration.apply_cert_config!
    
    Conjur::API.new_from_token(access_token)
  end

  def access_token
    JSON.parse(File.read("/run/conjur/access-token"))
  end
end

get '/' do
  variable = "test-app-db/password"
  value = nil

  begin
    access_token
  rescue StandardError => e
    $stderr.puts $!
    $stderr.puts $!.backtrace.join("\n")
    halt 500, "Error: Invalid access token."
  end
  
  begin
    value = conjur_api.variable(variable).value
  rescue RestClient::Forbidden => e
    $stderr.puts $!
    halt 500, "Error: Host #{access_token['data']} does not have access to variable #{variable}."
  end

  "test-app-db password: #{value}"
end
