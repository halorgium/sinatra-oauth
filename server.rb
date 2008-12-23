require File.dirname(__FILE__) + "/config/rubundler"
r = Rubundler.new
r.setup_env

require 'sinatra'
require 'oauth'
require 'oauth/server'
require 'oauth/signature'
require 'oauth/request_proxy/rack_request'

module OAuth
  class Token
    def to_query
      "oauth_token=#{escape(token)}&oauth_token_secret=#{escape(secret)}"
    end
  end
end

require 'dm-core'
require 'dm-validations'

DataMapper.setup(:default, 'sqlite3://sinatra-oauth.sqlite3')

error do
  exception = request.env['sinatra.error']
  puts "%s: %s" % [exception.class, exception.message]
  puts exception.backtrace
  "Sorry there was a nasty error"
end

delete "/db" do
  puts "Automigrating!"
  DataMapper.auto_migrate!
  c = Consumer.create(:name => "Awesome app",
                      :callback => "http://localhost:4568/callback",
                      :shared => 'key123',
                      :secret => 'sekret') || raise("Couldn't make the consumer: #{c.errors.inspect}")
  "OK"
end

post "/oauth/request_token" do
  Consumer.generate_request_token(request).query_string
end

get "/oauth/authorize" do
  if @request_token = RequestToken.first(:shared => params[:oauth_token])
    erb :authorize
  else
    raise Sinatra::NotFound, "No such request token"
  end
end

post "/oauth/authorize" do
  if request_token = RequestToken.first(:shared => params[:oauth_token])
    if request_token.authorize
      redirect request_token.consumer.callback
    else
      raise "FAILED TO SABVE"
    end
  else
    raise Sinatra::NotFound, "No such request token"
  end
end

post "/oauth/access_token" do
  if access_token = Consumer.generate_access_token(request)
    access_token.query_string
  else
    raise Sinatra::NotFound, "No such request token"
  end
end

get "/stove" do
  token = Consumer.check_access(request)
  "CAN HAS STOVE FOR #{token.inspect}"
end

class Consumer
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :nullable => false
  property :callback, String, :nullable => false
  property :shared, String, :nullable => false
  property :secret, String, :nullable => false

  has n, :request_tokens
  has n, :access_tokens

  def self.verify(request, type = nil, &block)
    token, consumer = nil, nil

    signature = OAuth::Signature.build(request) do |shared,consumer_shared|
      consumer = first(:shared => consumer_shared) || raise("Consumer not found")
      case type
      when :request
        token = consumer.request_tokens.first(:shared => shared) || raise("Request token not found")
      when :access
        token = consumer.access_tokens.first(:shared => shared) || raise("Access token not found")
      end
      [token && token.secret, consumer.secret]
    end

    if signature.verify
      type ? token : consumer
    else
      puts "Signature verify fail: Base: #{signature.signature_base_string}. Signature: #{signature.signature}"
      throw :halt, [401, "Signature verification failed"]
    end
  end

  def self.generate_request_token(request)
    verify(request).request
  end

  def self.generate_access_token(request)
    verify(request, :request).upgrade
  end

  def self.check_access(request)
    verify(request, :access)
  end

  def request
    token = request_tokens.new
    token.generate_credentials
    token.save || raise("Failed to generate the token: #{token.errors.inspect}")
    token
  end
end

module TokenMethods
  def generate_credentials
    self.shared, self.secret = OAuth::Server.new("http://localhost:4567").generate_credentials
  end

  def query_string
    OAuth::Token.new(shared, secret).to_query
  end
end

class RequestToken
  include DataMapper::Resource

  property :id, Serial
  property :shared, String, :nullable => false, :unique => true
  property :secret, String, :nullable => false, :unique => true
  property :authorized, Boolean
  property :consumer_id, Integer, :nullable => false

  belongs_to :consumer
  has n, :access_tokens

  def consumer
    Consumer.get(consumer_id)
  end

  def authorize
    @authorized = true
    save
  end

  def upgrade
    token = access_tokens.new(:consumer => consumer)
    token.generate_credentials
    token.save || raise("Failed to generate the token: #{token.errors.inspect}")
    token
  end

  include TokenMethods
end

class AccessToken
  include DataMapper::Resource

  property :id, Serial
  property :shared, String, :nullable => false, :unique => true
  property :secret, String, :nullable => false, :unique => true
  property :consumer_id, Integer, :nullable => false
  property :request_token_id, Integer, :nullable => false

  belongs_to :consumer
  belongs_to :request_token

  def consumer
    Consumer.get(consumer_id)
  end

  include TokenMethods
end

use_in_file_templates!

__END__

@@ authorize
<h2>You are about to authorize <%= @request_token.consumer.name %> (<%= @request_token.consumer.callback %>)</h2>
<form action="/oauth/authorize" method="post">
  <p>
    <input id="oauth_token" name="oauth_token" type="hidden" value="<%= @request_token.shared %>" />
  </p>

  <p>
    <input name="commit" type="submit" value="Activate" />
  </p>
</form>
