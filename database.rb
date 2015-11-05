### Bundler and gem setup
require "rubygems"
require "bundler/setup"

require "sqlite3"

class Database

    def initialize(name = "filesharer.db")
        @dbName = name;
        @db = SQLite3::Database.new name;

        createTables unless tablesExist?
    end



    def addFile(uid, filename, expire, password = nil, user = nil)
        # Add the file to the database
        # Will not actually move the file to the correct place in the filesystem

    end

    def fileCollected(uid, user = nil)
        # Update to indicate the file has been collected
        # Will not delete the file

    end

    def getUser(id)
        ## Get the info on a user
    end

    def authenticateUser(email, password)
        ## Hash the pw and authenticate it
        ## Also returns the user data

        if authenticated then
            return getUser id;
        else
            return false;
        end
    end


    ###### Private methods #######
    private
        def createTables
            # Create the sqlite tables here using @db.execute

            ## User table
            @db.execute <<-SQL
                CREATE TABLE IF NOT EXISTS User (
                    id       INT    PRIMARY KEY,
                    email    STRING UNIQUE,
                    password STRING NOT NULL
                );
            SQL

            ## Table for files that can only be picked up once
            @db.execute <<-SQL
                CREATE TABLE IF NOT EXISTS OneOffFiles (
                    id              INT      PRIMARY KEY,
                    userId          INT      NOT NULL
                                             REFERENCES User (id) ON DELETE CASCADE
                                                                  ON UPDATE CASCADE,
                    uid             STRING   NOT NULL,
                    filename                 NOT NULL,
                    expire          DATETIME,
                    collected       BOOLEAN  DEFAULT (0) 
                                             NOT NULL,
                    collectedUserId          REFERENCES User (id),
                    password        STRING,
                    requireLogin    BOOLEAN  NOT NULL
                                             DEFAULT (0) 
                );
            SQL


        end

        def tablesExist?
            # Do some SQL checks here to see if the db is set up
            tables = ['User', 'OneOffFiles'];
            sql = <<-SQL
                SELECT name FROM sqlite_master WHERE type='table' AND name in (?, ?);
            SQL

            result = @db.execute sql, tables

            return result.count;
            return result.count == tables.count;
        end

end
