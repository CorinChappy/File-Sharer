### Bundler and gem setup
require "rubygems"
require "bundler/setup"

require "sqlite3"

class Database 

    def initialize(name = "filesharer.db")
        @dbName = name;
        @db = SQLite3::Database.new name;

        createTables unless tablesExist?;
    end



    def addFile(uid, expire, user)
        # Add the file to the database
        # Will not actually move the file to the correct place in the filesystem

    end

    def fileCollected(uid, user = nil)
        # Update to indicate the file has been collected
        # Will not delete the file

    end

    def getUser(username)
        ## Get the info on a user
    end

    def authenticateUser(username, password)
        ## Hash the pw and authenticate it
        ## Also returns the user data

        if authenticated then
            return getUser username;
        else
            return false;
        end
    end


    ###### Private methods #######
    private
        def createTables
            # Create the sqlite tables here using @db.execute
        end

        def tablesExist?
            # Do some SQL checks here to see if the db is set up

            return true;
        end

end
