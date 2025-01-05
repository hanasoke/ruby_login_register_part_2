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
# begin 
#     DB.execute("ALTER TABLE profiles ADD COLUMN reset_token TEXT;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'reset_token' already exist or another error occured: #{e.message}"
# end 

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
# begin 
#     DB.execute("ALTER TABLE cars ADD COLUMN country TEXT;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'country' already exists or another error accored: #{e.message}"
# end 

# Add the `chair` column if it doesn't exist
# begin 
#     DB.execute("ALTER TABLE cars ADD COLUMN chair INTEGER;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'chair' already exists or another error occured: #{e.message}"
# end 

# Add the `photo` column if it doesn't exist
# begin 
#     DB.execute("ALTER TABLE cars ADD COLUMN photo TEXT;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'photo' already exists or another error occured: #{e.message}"
# end 

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS motors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT,
        brand TEXT,
        chair TEXT,
        country TEXT,
        manufacture TEXT,
        price TEXT,
        photo TEXT, 
        warranty TEXT
    );
SQL

# Step 1: Create a new table with the updated schema 
# DB.execute <<-SQL 
#     CREATE TABLE IF NOT EXISTS motors_new (
#         id INTEGER PRIMARY KEY AUTOINCREMENT,
#         name TEXT,
#         type TEXT,
#         brand TEXT,
#         chair INTEGER,
#         country TEXT,
#         manufacture TEXT,
#         price TEXT
#     );
# SQL

# Step 2: Copy data from the old table to the new table 
# DB.execute <<-SQL
#     INSERT INTO motors_new (id, name, type, brand, chair, country, manufacture, price)
#     SELECT id, name, type, brand, CAST(chair AS INTEGER), country, manufacture, price FROM motors;
# SQL

# Step 3: Drop the old table
# DB.execute("DROP TABLE motors;")

# Step 4: Rename the new table to the original name
# DB.execute("ALTER TABLE motors_new RENAME TO motors;")

# begin 
#     DB.execute("ALTER TABLE motors ADD COLUMN warranty TEXT;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'warranty' already exists or another error occured: #{e.message}"
# end 

# DB.execute("DROP TABLE IF EXISTS motors;")

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS leafs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT,
        age INTEGER,
        description TEXT
    );
SQL

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS trees (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        leaf_id INTEGER,
        age INTEGER,
        seed_id INTEGER,
        description TEXT,
        FOREIGN KEY (leaf_id) REFERENCES leafs (id),
        FOREIGN KEY (seed_id) REFERENCES seeds (id)
    );
SQL

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS seeds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
    );
SQL

# DB.execute("PRAGMA foreign_keys = ON;")

# puts DB.execute("PRAGMA foreign_key_list(trees);")

# begin 
#     DB.execute("ALTER TABLE trees ADD COLUMN name TEXT;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'name' already exists or another error occured: #{e.message}"
# end 