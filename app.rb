### Bundler and gem setup
require "rubygems"
require "bundler/setup"

require "sinatra/base"
require "erubis"

require "json"

require "./database.rb"


class FileSharer < Sinatra::Application
    
    enable :sessions

    database = Database.new;


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
        user = database.authenticateUser(email, password);

        if !user then
            erb :login, { "error" => "Invalid email or password", "email" => email }
        else
            session["userId"] = user["id"];
            session["email"] = user["email"];
            redirect to("/");
        end
    end


    get "/logout" do
        session.delete "userId"
        session.delete "email"
        redirect to("/");
    end


    get "/signup" do
        erb :signup
    end

    post "/signup" do
        email = params["email"];
        password = params["password"];
        firstName = params["firstName"];
        lastName = params["lastName"];

        ## Attempt to create
        user = database.createUser(email, password, firstName, lastName);

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
        end while database.uidInUse? uid;

        filename = params["file"][:filename]
        dir = File.join("uploads", uid)

        Dir.mkdir dir unless File.exists? dir

        File.open(File.join(dir, filename), "w") { | file |
            file.write(params["file"][:tempfile].read)
        }

        password = params["password"]
        user = session["userId"]
        requireLogin = !!params["requireLogin"]

        database.addFile(uid, filename, nil, password, user, requireLogin)

        { uid: uid, filename: filename }.to_json;
    end





    get "/file/:uid" do | uid |
        # Show a HTML interface for the file
        ## Get the database info on a file
        fileData = database.getFileData uid;

        if fileData == nil then
            halt 404, erb(:file, { "error" => "File not found: Unrecoginised ID"})
        end

        if fileData["collected"] > 0 then
            halt 400, erb(:file, { "error" => "File already collected" })
        end

        if fileData["requireLogin"] > 0 && (session["userId"] == nil || !session["userId"].is_a?(Integer)) then
            return redirect to("/login"), 307
        end

        if fileData["password"] != nil && params["password"] != nil && params["password"] != password then
            halt 400, erb(:file, { "passwordRequired" => true })
        end


        ## Checks have passed, show the page
        erb :file, {
            "fileData" => {
                "uid" => fileData["uid"],
                "filename" => fileData["filename"],
                "expire" => fileData["expire"]
            }
        };
    end


    ## Download function so both get and post requests can be used
    downloadLambda = lambda { | uid |
        # Serve the file directly with the "Content-Disposition: attachment" header to force browser download
        ## First check if the file has already been collected and so on
        fileData = database.getFileData uid;

        # 404 on actual not found and file collection
        if fileData == nil || fileData["collected"] > 0 then
            halt 404, "file not found"
        end

        if fileData["requireLogin"] > 0 && (session["userId"] == nil || !session["userId"].is_a?(Integer)) then
            halt 400, "login required"
        end

        if fileData["password"] != nil && params["password"] != nil && params["password"] != password then
            halt 400, "password required"
        end


        ## Update the DB to mark file as collected
        database.collectFile uid, session["userId"];

        ## Serve the file
        headers({ "Content-Disposition" => "attachment; filename=\"" + fileData["filename"] + "\"" });
        send_file File.join("uploads", uid, fileData["filename"]);
        ##### This doesn't actually delete the files, might want to make some mechanism to delete files at a later point
    }

    get "/file/:uid/download", &downloadLambda
    post "/file/:uid/download", &downloadLambda

end



## Run the sinatra app
FileSharer::run!
