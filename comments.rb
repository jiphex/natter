#!/usr/bin/env ruby

require 'rubygems'

# require 'bundler/setup'

require 'redis'
require 'sinatra'
require 'json'

# require 'digest/sha1'

$: << "."

require 'lib/comment'
require 'lib/post'
require 'lib/errors'
require 'lib/config'

config = Comments::Config.new

disable :protection

before do
  headers "Access-Control-Allow-Origin" => config["aca_origin"]
  content_type "text/json"
end

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end
end

get '/' do
  return "Hello, this is just the comment server for http://drax.tlyk.eu. Move along."
end

get '/show' do
  begin
    pozt = Comments::Post.find(params[:cid])
  rescue Comments::NoSuchPost
    return [].to_json
  rescue Redis::CannotConnectError
    status 500
    return ["NoRedis"]
  end
  comments = []
  posts_json = pozt.comments.map{|c|
    comments << {"body"=>c.body,
     "author"=>c.author}.to_json
  }
  puts comments.to_json
  return comments.to_json
end

post '/submit' do
  thepost = nil
  begin
    thepost = Comments::Post.find(params[:submitckey])
  rescue Comments::NoSuchPost
    # status 404
    # return ["NoSuchPost"].to_json
    thepost = nil
  end
  c = Comments::Comment.new({
    :body=> params[:submitbody],
    :author=> params[:submitauthor],
    :email=>params[:submitemail],
    :ip=> request.ip,
    :post=>thepost,
    "referrer"=> request.referrer,
  })
  ckey = params[:submitckey]
  if c.is_valid?
    if c.spam?
      status 401
      return ["CommentIsSpam"].to_json
    else
      c.save!
    end
  else
    status 400
    return  c.validation_errors.to_json
  end
  db = Redis.new
  db.lpush("comment:"+ckey,c.key)
  return "ok".to_json
end
