### Bundler and gem setup
require "rubygems"
require "bundler/setup"

require "sinatra/base"
require "erubis"

require "json"

require "./database.rb"


class FileSharer < Sinatra::Application
    
    enable :sessions

    @@database = Database.new;


    ## Create uploads dir if needed
    Dir.mkdir "uploads" unless File.exists? "uploads"

    get "/" do
        erb :index
    end

    #### Log in and auth routes ####
    get "/login" do
        erb :login
    end

    post "/login" do
        email = params["email"];
        password = params["password"];

        ## Authenticate
        user = @@database.authenticateUser(email, password);

        if !user then
            erb :login, { "error" => "Invalid email or password", "email" => email }
        else
            session["userId"] = user["id"];
            session["email"] = user["email"];
            redirect to("/");
        end
    end

    get "/signup" do
        erb :signup
    end

    post "/signup" do
        email = params["email"];
        password = params["password"];

        ## Attempt to create
        user = @@database.createUser(email, password);

        if !user then
            erb :signup, { "error" => "That email is already registered" }
        else
            session["userId"] = user["id"];
            session["email"] = user["email"];
            redirect to("/");
        end
    end


    put "/upload" do
        content_type :json
        # Upload here
        return false.to_json if !params["file"];

        ## Generate a uid for this file
        begin
            uid = SecureRandom.uuid
        end while @@database.uidInUse? uid;

        filename = params["file"][:filename]
        dir = File.join("uploads", uid)

        Dir.mkdir dir unless File.exists? dir

        File.open(File.join(dir, filename), "w") { | file |
            file.write(params["file"][:tempfile].read)
        }

        password = params["password"]
        user = session["userId"]
        requireLogin = !!params["requireLogin"]

        @@database.addFile(uid, filename, nil, password, user, requireLogin)

        { uid: uid, filename: filename }.to_json;
    end



    get "/file/:uid" do | uid |
        ## Show a HTML interface for the file
    end

    get "/file/:uid/download" do | uid |
        ## Serve the file directly with the "Content-Disposition: attachment" header to force browser download
    end

end



## Run the sinatra app
FileSharer::run!
