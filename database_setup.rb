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

# Create the `cars` table if it doesn't exist
DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS cars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT, 
        brand TEXT,
        manufacture TEXT, 
        price TEXT
    );
SQL

# Add the `country` column if it doesn't exist
begin 
    DB.execute("ALTER TABLE cars ADD COLUMN country TEXT;")
rescue SQLite3::SQLException => e 
    puts "Column 'country' already exists or another error accored: #{e.message}"
end 

# Add the `chair` column if it doesn't exist
begin 
    DB.execute("ALTER TABLE cars ADD COLUMN chair INTEGER;")
rescue SQLite3::SQLException => e 
    puts "Column 'chair' already exists or another error occured: #{e.message}"
end 

# Add the `photo` column if it doesn't exist
begin 
    DB.execute("ALTER TABLE cars ADD COLUMN photo TEXT;")
rescue SQLite3::SQLException => e 
    puts "Column 'photo' already exists or another error occured: #{e.message}"
end 
