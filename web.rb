require 'sinatra/base'

class BobStatus < Sinatra::Base
  get '/' do
    "hey Bob!"
  end
end
