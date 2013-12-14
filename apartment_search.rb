require 'rubygems'
require 'bundler'
require 'slim'
require 'mongoid'
require 'sinatra-websocket'
require 'coffee-script'

Bundler.require
require 'sinatra/reloader' if development?

configure :development do
  register Sinatra::Reloader
  # Mongoid.configure.connect_to("yad2_spy")
  Mongoid.load!("config/mongoid.yml")
end
require './lib/scraper'
require './lib/crawler'
require './lib/model'

set :sockets, { crawlers: [] }

get '/javascripts/:filename' do
  coffee "../public/javascripts/#{params[:filename]}".to_sym
end

get '/sounds/:filename' do
  run Rack::File.new("./public/sounds/#{params[:filename]}")
end

get "/yad2/rent" do
  get_list
end


get "/yad2/crawl/:query_id" do
  if request.websocket?
    query = Query.find_by id: params[:query_id]
    init_crawler_socket(query)
  else
    raise "this url serves only websockets"
  end
end

private

def init_crawler_socket(query)
  request.websocket do |ws|
    ws.onopen do
      ws.send({json: :data}.to_json)
      crawler(query).start do |new_apartments|
        ws.send(new_apartments.to_json)
        new_apartments.each(&:seen!)
      end
      settings.sockets[:crawlers] << ws
    end
    ws.onmessage do |msg|
      # EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
    end
    ws.onclose do
      warn("wetbsocket closed")
      crawler(query).stop
      settings.sockets[:crawlers].delete(ws)
    end
  end
end

def crawler(query)
  Crawler.instance_for(query)
end

def get_list
  @query = Query.fetch request.params
  slim :list
end



