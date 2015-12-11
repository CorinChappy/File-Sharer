### Bundler and gem setup
require "rubygems"
require "bundler/setup"

require "sinatra/base"
require "erubis"
require "tilt/erubis"

require "json"
require "net/http"
require "uri"

require "./database.rb"


class FileSharer < Sinatra::Application
    
    enable :sessions

    set :session_secret, "super secret thing"

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
            erb :login, :locals => { :err => "Invalid email or password", :email => email }
        else
            session[:user] = user;
            redirect to("/");
        end
    end


    get "/logout" do
        session.delete :user
        redirect to("/");
    end


    get "/signup" do
        erb :signup
    end

    post "/signup" do
        email = params["email"];
        password = params["password"];
        repassword = params["repassword"];
        firstName = params["firstName"];
        lastName = params["lastName"];

        unless /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/ =~ email then
            return erb :signup, :locals => {
                :err => "Email address not valid",
                :email => email,
                :firstName => firstName,
                :lastName => lastName
            };
        end


        if password.length < 6 then
            return erb :signup, :locals => {
                :err => "Password must be at least 6 characters long",
                :email => email,
                :firstName => firstName,
                :lastName => lastName
            };
        end

        unless password == repassword then 
            return erb :signup, :locals => {
                :err => "Passwords do not match",
                :email => email,
                :firstName => firstName,
                :lastName => lastName
            };
        end

        ## Attempt to create
        user = database.createUser(email, password, firstName, lastName);

        if !user then
            erb :signup, :locals => { :err => "That email is already registered" }
        else
            session[:user] = user
            redirect to("/");
        end
    end


    post "/upload" do
        content_type :json
        # Upload here
        return false.to_json if !params["file"] && !params["url"];

        ## Generate a uid for this file
        begin
            uid = SecureRandom.uuid
        end while database.uidInUse? uid;


        dir = File.join("uploads", uid)
        Dir.mkdir dir unless File.exists? dir

        ## Case for files
        if params["file"] then
            filename = params["file"][:filename]

            File.open(File.join(dir, filename), "w") { | file |
                file.write(params["file"][:tempfile].read)
            }
        else
            ## Case for URLs
            url = params["url"]

            uri = URI.parse(url)
            filename = File.basename(uri.path)

            response = Net::HTTP.get_response(uri)

            if response.code.to_i >= 300 then
                return { err: "Code greater than 299 returned for URL" }.to_json
            end

            File.open(File.join(dir, filename), "w") { | file |
                file.write(response.body)
            }
        end

        password = params["password"]
        user = session[:user] && session[:user][:id]
        requireLogin = !!params["requireLogin"]

        database.addFile(uid, filename, nil, password, user, requireLogin)

        { uid: uid, filename: filename }.to_json;
    end

    get "/uploads" do
        unless session[:user] then
            redirect to("/login"), 307
        end
        
        user = session[:user][:id]
        uploads = database.getUploads user
        
        uploadData = uploads.map { | upload | 
            {
                :filename => upload["filename"],
                :uid => upload["uid"],
                :collected => upload["collected"],
                :collectedUserId => upload["collectedUserId"]
            }
        }

        erb :uploads, :locals => {
            :uploadData => uploadData
        };

    end

    get "/file" do
        erb :file
    end

    get "/file/:uid" do | uid |
        # Show a HTML interface for the file
        ## Get the database info on a file
        fileData = database.getFileData uid;


        if fileData == nil then
            halt 404, erb(:file, { :err => "File not found: Unrecoginised ID"})
        end

        if fileData["collected"] > 0 then
            halt 400, erb(:file, { :err => "file has been collected" })
        end

        if fileData["requireLogin"] > 0 && (session[:user] == nil || !session[:user][:id].is_a?(Integer)) then
            return redirect to("/login"), 307
        end

        if fileData["password"] != nil && params["password"] != nil && params["password"] != password then
            halt 400, erb(:file, { "passwordRequired" => true })
        end


        ## Checks have passed, show the page

        # Is there an uploader?
        if fileData["userId"] then
            uploader = {
                :email => fileData["email"],
                :firstName => fileData["firstName"],
                :lastName => fileData["lastName"]
            }
        else
            uploader = nil
        end


        erb :file, :locals => {
            :fileData => {
                :uid => fileData["uid"],
                :filename => fileData["filename"],
                :expire => fileData["expire"],
                :collected => fileData["collected"]
            },
            :uploader => uploader
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

        if fileData["requireLogin"] > 0 && (session[:user] == nil || !session[:user][:id].is_a?(Integer)) then
            halt 400, "login required"
        end

        if fileData["password"] != nil && params["password"] != nil && params["password"] != password then
            halt 400, "password required"
        end


        ## Update the DB to mark file as collected
        if session[:user] && session[:user][:id] then
            database.collectFile uid, session[:user][:id];
        else
            database.collectFile uid 
        end

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
