### Bundler and gem setup
require "rubygems"
require "bundler/setup"

require "sqlite3"
require "bcrypt"


class Database

    def initialize(name = "filesharer.db")
        @dbName = name;
        @db = SQLite3::Database.new name;
        @db.results_as_hash = true;

        createTables unless tablesExist?
    end


    def addFile(uid, filename, expire = nil, password = nil, user = nil, requireLogin = false)
        # Add the file to the database
        # Will not actually move the file to the correct place in the filesystem
        sql = <<-SQL
            INSERT INTO `OneOffFiles`
                (`userId`, `uid`, `filename`, `expire`, `password`, `requireLogin`)
                VALUES (?, ?, ?, ?, ?, ?)
        SQL

        requireLogin = requireLogin ? 1 : 0;

        @db.execute sql, [ user, uid, filename, expire, password, requireLogin ]

        true;
    end

    def getFileData(uid)
        ## Get from da database
        sql = <<-SQL
            SELECT f.*,  u.`email`, u.`firstName`, u.`lastName`
            FROM `OneOffFiles` f
            LEFT JOIN `User` u ON f.`userId` = u.`id`
            WHERE f.`uid` = ?
        SQL

        @db.execute(
            sql,
            [ uid ]
        ).first;
    end

    # Will also return false if the file does not exist at all
    def fileCollected?(uid)
        collected = @db.execute(
            "SELECT `collected` FROM `OneOffFiles` WHERE uid = ?",
            [ uid ]
        ).first;

        return collected != nil && collected["collected"] > 0;
    end

    def collectFile(uid, user = nil)
        # Update to indicate the file has been collected
        # Will not delete the file
        sql = <<-SQL
            UPDATE `OneOffFiles` 
                SET collected = ?, collectedUserId = ?
                WHERE uid = ?
        SQL

        @db.execute sql, [ 1, user, uid ]

        true;
    end

    def getUser(id)
        ## Get the info on a user
        @db.execute(
            "SELECT `id`, `email`, `firstName`, `lastName` FROM `User` WHERE `id` = ?",
            [ id ]
        ).first;
    end

    def authenticateUser(email, password)
        ## Hash the pw and authenticate it
        ## Also returns the user data
        user = @db.execute(
            "SELECT `id`, `email`, `password` FROM `User` WHERE `email` = ?",
            [ email ]
        ).first;

        if !user then
            return false
        end


        pw = BCrypt::Password.new(user["password"]);

        authenticated = (user != nil &&  pw == password);

        if authenticated then
            return { id: user["id"], email: user["email"] };
        else
            return false;
        end
    end

    def createUser(email, password, firstName = nil, lastName = nil)
        # Create user col in the DB
        ## Hash the password
        hash = BCrypt::Password.create(password);

        exist = @db.execute(
            "SELECT `id` FROM `User` WHERE `email` = ?",
            [ email ]
        ).count > 0;

        return false if exist;

        @db.execute(
            "INSERT INTO `User` (`email`, `password`, `firstName`, `lastName`) VALUES (?,?,?,?)",
            [ email, hash, firstName, lastName ]
        );

        rowid = @db.last_insert_row_id;

        return getUser rowid;
    end

    def uidInUse?(uid)
        @db.execute(
            "SELECT `id` FROM `OneOffFiles` WHERE `uid` = ?",
            [ uid ]
        ).count > 0;
    end


    ###### Private methods #######
    private
        def createTables
            # Create the sqlite tables here using @db.execute

            ## User table
            @db.execute <<-SQL
                CREATE TABLE IF NOT EXISTS User (
                    id        INTEGER PRIMARY KEY AUTOINCREMENT,
                    email     STRING  UNIQUE,
                    password  STRING  NOT NULL,
                    firstName STRING,
                    lastName  STRING
                );
            SQL

            ## Table for files that can only be picked up once
            @db.execute <<-SQL
                CREATE TABLE IF NOT EXISTS OneOffFiles (
                    id              INTEGER  PRIMARY KEY AUTOINCREMENT,
                    userId          INTEGER  REFERENCES User (id) ON DELETE CASCADE
                                                                  ON UPDATE CASCADE,
                    uid             STRING   NOT NULL
                                             UNIQUE,
                    filename                 NOT NULL,
                    expire          DATETIME,
                    collected       BOOLEAN  DEFAULT (0) 
                                             NOT NULL,
                    collectedUserId INTEGER  REFERENCES User (id),
                    password        STRING,
                    requireLogin    BOOLEAN  NOT NULL
                                             DEFAULT (0) 
                );
            SQL

            true;
        end

        def tablesExist?
            # Do some SQL checks here to see if the db is set up
            tables = ['User', 'OneOffFiles'];
            sql = "SELECT name FROM sqlite_master WHERE type='table' AND name in (#{ Array.new(tables.count).fill('?').join(',') });"

            result = @db.execute sql, tables

            return result.count == tables.count;
        end

end
