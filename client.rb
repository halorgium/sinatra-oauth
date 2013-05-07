require 'bundler/setup'

require 'sinatra'
require 'rest_client'
require 'oauth'
require 'oauth/consumer'

use Rack::Session::Cookie, :secret => 'foo'

set :port, 4568

before do
  session[:kitchen] ||= {}
  @kitchen = Kitchen.new(session[:kitchen])
end

error do
  exception = request.env['sinatra.error']
  puts "%s: %s" % [exception.class, exception.message]
  puts exception.backtrace
  "Sorry there was a nasty error"
end

get "/" do
  if @kitchen.ready?
    erb :ready
  else
    erb :start
  end
end

get "/reset" do
  session.clear
  redirect '/'
end

get '/bootstrap' do
  Kitchen.reset
  redirect '/'
end

get "/request" do
  @kitchen.request
  session[:kitchen] = @kitchen.session_data
  redirect @kitchen.url
end

get '/callback' do
  @kitchen.upgrade
  session[:kitchen] = @kitchen.session_data
  redirect '/'
end

get '/stove' do
  headers "Content-Type" => "text/plain"
  @kitchen.get("/stove").body
end

class Kitchen
  BASE = "http://localhost:4567"

  def self.reset
    RestClient.delete("#{BASE}/db")
  end

  def initialize(options = {})
    request_token, request_token_secret = options[:request_token], options[:request_token_secret]
    if request_token && request_token_secret
      @request_token = OAuth::RequestToken.new(consumer, request_token, request_token_secret)
    end

    access_token, access_token_secret = options[:access_token], options[:access_token_secret]
    if access_token && access_token_secret
      @access_token = OAuth::AccessToken.new(consumer, access_token, access_token_secret)
    end
  end

  def ready?
    @access_token
  end

  def request
    @request_token = consumer.get_request_token
  end

  def session_data
    data = {}
    if @request_token
      data[:request_token] = @request_token.token
      data[:request_token_secret] = @request_token.secret
    end
    if @access_token
      data[:access_token] = @access_token.token
      data[:access_token_secret] = @access_token.secret
    end
    data
  end

  def url
    @request_token.authorize_url
  end

  def upgrade
    @access_token = @request_token.get_access_token
  end

  def get(*args)
    @access_token.get(*args)
  end

  def consumer
    @consumer ||= OAuth::Consumer.new("key123", "sekret",
                                      :site => BASE,
                                      :request_token_path => "/oauth/request_token",
                                      :access_token_path => "/oauth/access_token",
                                      :authorize_path => "/oauth/authorize")
  end
end

__END__

@@ start
<a href="/request">Get access</a>

@@ ready
<h2>You are ready for access!</h2>
<a href="/stove">Try it!</a>
