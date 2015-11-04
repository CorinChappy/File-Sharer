### Bundler and gem setup
require "rubygems"
require "bundler/setup"

require "sinatra/base"
require "erubis"

require "json"

require "./database.rb"


class FileSharer < Sinatra::Application
    
    get "/" do
        erb :index
    end


    put "/upload" do
        content_type :json
        ## Upload here

        { uid: 123456 }.to_json;
    end



    get "file/:uid" do | uid |
        ## Show a HTML interface for the file
    end

    get "file/:uid/download" do | uid |
        ## Serve the file directly with the "Content-Disposition: attachment" header to force browser download
    end

end



## Run the sinatra app
FileSharer::run!
