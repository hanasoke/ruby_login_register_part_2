require 'sqlite3'
require 'bcrypt'

DB = SQLite3::Database.new('profiles.db')
DB.results_as_hash = true

# Create the `profiles` table if it doesn't exist
DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        username TEXT UNIQUE,
        email TEXT,
        password TEXT,
        country TEXT
    );
SQL

# Add the `reset_token` column if it doesn't exist 
begin 
    DB.execute("ALTER TABLE profiles ADD COLUMN reset_token TEXT;")
rescue SQLite3::SQLException => e 
    puts "Column 'reset_token' already exist or another error occured: #{e.message}"
end 