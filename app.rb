require 'sinatra'
require 'bcrypt'
require_relative 'database_setup'

enable :sessions 

# Helper methods 
def logged_in?
    session[:profile_id] != nil
end

def current_profile 
    @current_profile ||= DB.execute("SELECT * FROM profiles WHERE id = ?", [session[:profile_id]]).first if logged_in?
end 

def validate_profile(name, username, email, password, re_password, country)
    errors = []
    # check for empty fields 
    errors << "Username cannot be blank." if username.nil? || username.strip.empty?
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?
    errors << "Password cannot be blank." if password.nil? || password.strip.empty?
    errors << "Country cannot be blank." if country.nil? || country.strip.empty?

    # validate email 
    email_errors = validate_email(email)
    errors.concat(email_errors)

    # check if password match
    errors << "Password do not match." if password != re_password
    errors
end

def validate_car(name, type, brand, chair, country, manufacture, price, id = nil) 
    errors = []
    # check for empty fields
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    # Check for unique name 
    query = id ? "SELECT id FROM cars WHERE LOWER(name) = ? AND id != ?" : "SELECT id FROM cars WHERE LOWER(name) = ?"
    existing_car = DB.execute(query, id ? [name.downcase, id] : [name.downcase]).first
    errors << "Name already exist. Plase choose a different name." if existing_car

    # Other Validation
    errors << "type cannot be blank." if type.nil? || type.strip.empty?
    errors << "brand cannot be blank." if brand.nil? || brand.strip.empty?

    if chair.nil? || chair.to_i < 1 || chair.to_i > 10
        errors << "Chair must be a number between 1 and 10."
    end 

    errors << "country cannot be blank." if country.nil? || country.strip.empty?
    
    # Validate manufacture date
    if manufacture.nil? || manufacture.strip.empty? || !manufacture.match(/^\d{4}-\d{2}-\d{2}$/)
        errors << "Manufacture date must be a valid date (YYYY-MM-DD)."
    end 

    # check for valid price
    if price.nil? || price.strip.empty?
        errors << "price cannot be blank."

    elsif price.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Price must be a valid number."
    
    elsif price.to_f <= 0
        errors << "Price must be a positive number"

    end 
    
    errors
end

def validate_motor(name, type, brand, chair, country, manufacture, price, id = nil) 
    errors = []
    # check for empty fields
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    # Check for unique name 
    query = id ? "SELECT id FROM motors WHERE LOWER(name) = ? AND id != ?" : "SELECT id FROM motors WHERE LOWER(name) = ?"
    existing_motor = DB.execute(query, id ? [name.downcase, id] : [name.downcase]).first
    errors << "Name already exist. Please choose a different name." if existing_motor

    # Other Validation
    errors << "type cannot be blank." if type.nil? || type.strip.empty?
    errors << "brand cannot be blank." if brand.nil? || brand.strip.empty?

    if chair.nil? || chair.to_i < 1 || chair.to_i > 3
        errors << "Chair must be a number between 1 and 3"
    end 

    errors << "country cannot be blank." if country.nil? || country.strip.empty?
    
    # Validate manufacture date
    if manufacture.nil? || manufacture.strip.empty? || !manufacture.match(/^\d{4}-\d{2}-\d{2}$/)
        errors << "Manufacture date must be a valid date (YYYY-MM-DD)."
    end 

    # check for valid price
    if price.nil? || price.strip.empty?
        errors << "price cannot be blank."

    elsif price.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Price must be a valid number."
    
    elsif price.to_f <= 0
        errors << "Price must be a positive number"

    end 
    
    errors
end

def editing_profile(name, username, email, password, re_password, country, editing: false)
    errors = []
    errors << "Username cannot be blank." if username.nil? || username.strip.empty?
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?
    errors << "Country cannot be blank." if country.nil? || country.strip.empty?

    # Skip password validation if editing and password is blank
    unless editing && (password.nil? || password.strip.empty?)
        errors << "Password cannot be blank." if password.nil? || password.strip.empty?
        errors << "Passwords do not match." if password != re_password
    end
    
    # Validate email
    errors.concat(validate_email(email))
    errors
end

def validate_profile_login(email, password)
    errors = []
    errors << "Password cannot be blank." if password.nil? || password.strip.empty?
    errors.concat(validate_email(email)) # Validate email format
    errors 
end

# validate email using the method above
def validate_email(email)
    errors = []
    # Regular expression for email validation
    email_regex = /\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z/

    # check if email is blank
    if email.nil? || email.strip.empty?
        errors << "Email cannot be blank."
    elsif email !~ email_regex
        # check if email matches the regular expression
        errors << "Email format is invalid"
    end

    errors
end

def validate_photo(photo) 
    errors = []

    if photo.nil? || photo[:tempfile].nil?
        errors << "Photo is required."
    else 
        # Check file type
        valid_types = ["image/jpeg", "image/png", "image/gif"]
        unless valid_types.include?(photo[:type])
            errors << "Photo must be a JPG, PNG, or GIF file."
        end 

        # Check file size (5MB max)
        max_size = 4 * 1024 * 1024 # 4MB in bytes
        min_size = 2 * 20000 #40 KB 
        if photo[:tempfile].size > max_size
            errors << "Photo size must be less than 4MB."
        elsif photo[:tempfile].size < min_size
            errors << "Photo size must be greater than 40KB."
        end 
    end 
    errors
end

def validate_file(file)
    errors = []

    if file.nil? || file[:tempfile].nil?
        errors << "File is required."
    else 
        # Check file type
        valid_types = ["application/pdf",
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                        "text/plain"]
        unless valid_types.include?(file[:type])
            errors << "File must be a PDF, DOCX, or TXT file."
        end

        # Check file size (10MB max, 1KB min)
        max_size = 10 * 1024 * 1024 # 10MB in bytes
        min_size = 1 * 1024         # 1KB in bytes
        if file[:tempfile].size > max_size
            errors << "File size must be less than 10MB."
        elsif file[:tempfile].size < min_size
            errors << "File size must be greater than 1KB."
        end        
    end
    errors
end

def format_rupiah(number) 
    "Rp #{number.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
end

def validate_leaf(name, type, age, description, id = nil) 
    errors = []
    errors << "Name Cannot be blank." if name.nil? || name.strip.empty?
    errors << "Type Cannot be blank." if type.nil? || type.strip.empty?
    
    # check for valid age
    if age.nil? || age.strip.empty?
        errors << "Age cannot be blank."
    elsif age.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Age must be a valid number."
    elsif age.to_f <= 0
        errors << "Age must be a positive number"
    end 

    errors << "Description Cannot be blank." if description.nil? || description.strip.empty?
    errors 
end 

def validate_seed(name, id = nil) 
    errors = []
    errors << "Name Cannot be blank." if name.nil? || name.strip.empty?
    errors
end 

def validate_tree(name, type, leaf_id, seed_id, age, description, id = nil)
    errors = []

    errors << "Name is required." if name.nil? || name.strip.empty?
    errors << "Type is required." if type.nil? || type.strip.empty?
    errors << "Leaf is required." if leaf_id.nil? || leaf_id.strip.empty?
    errors << "Seed is required." if seed_id.nil? || seed_id.strip.empty?

    seed_exists = DB.get_first_value("SELECT COUNT(*) FROM seeds WHERE id = ?", [seed_id.to_i])
    leaf_exists = DB.get_first_value("SELECT COUNT(*) FROM leafs WHERE id = ?", [leaf_id.to_i])
    errors << "Leaf ID does not exist." unless leaf_exists&.positive? 
    errors << "Seed ID does not exist." unless seed_exists&.positive?
     
    # Validate age
    if age.nil? || age.strip.empty?
        errors << "Age cannot be blank."
    elsif age.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Age must be a valid number."
    elsif age.to_f <= 0
        errors << "Age must be a positive number."
    end 
    # Validate description
    errors << "Description is required." if description.nil? || description.strip.empty?

    errors 
end 

# Routes 
get '/' do 
    @title = "Homepage"
    if logged_in?
        erb :index, layout: :'layouts/main'
    else 
        redirect '/login'
    end
end

get '/show' do 
    @title = 'My Profile'
    erb :'profile/show', layout: :'layouts/main'
end 

# Read all users
get '/user_list' do
    @title = "User List"
    @profiles = DB.execute("SELECT * FROM profiles")
    erb :'user/user_list', layout: :'layouts/main'
end 

# Registration
get '/register' do 
    @errors = []
    @title = "Register Dashboard"
    erb :register, layout: :'layouts/admin'
end 

post '/register' do 
    @errors = validate_profile(params[:name], params[:username], params[:email], params[:password], params[:'re-password'], params[:country])

    # Flash message
    session[:success] = "Your Account has been registered."

    if @errors.empty? 
        name = params[:name]
        username = params[:username]
        email = params[:email]
        password = BCrypt::Password.create(params[:password])
        country = params[:country]

        begin 
            DB.execute("INSERT INTO profiles (name, username, email, password, country) VALUES (?, ?, ?, ?, ?)", [name, username, email, password, country])
            redirect '/login'
            
        rescue SQLite3::ConstraintException
            @errors << "Username already exists"
        end
         
    end 

    erb :register, layout: :'layouts/admin'
end 

helpers do 
    def flash(type)
        message = session[type]
        session[type] = nil #clear flash message after displaying
        message
    end 
end 

# login
get '/login' do
    @errors = []
    @title = "Login Dashboard"
    erb :login, layout: :'layouts/admin'
end

post '/login' do 
    @errors = validate_profile_login(params[:email], params[:password])

    if @errors.empty?
        email = params[:email]
        profile = DB.execute("SELECT * FROM profiles WHERE email = ?", [email]).first

        if profile && BCrypt::Password.new(profile['password']) == params[:password]
            session[:profile_id] = profile['id']
            redirect '/' # Redirect to home after successful login 
        else 
            @errors << "Invalid email or password"           
        end
    end
    erb :login, layout: :'layouts/admin'
end 

# Form to view a profile 
get '/profiles/:id/view' do 
    @title = "View the Profile"
    @profile = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first
    erb :'user/view', layout: :'layouts/main' 
end

get '/profiles/:id/view' do 
    @title = "Edit the Profile"
    @profile = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first
    erb :'profile/edit', layout: :'layouts/main'
end 

# logout
get '/logout' do 
    session.clear 
    redirect '/login'
end

# Form to edit the current user's profil
get '/profiles/edit' do 
    redirect '/login' unless logged_in?

    @title = "Edit Your Profile"
    @profile = current_profile
    @errors = []
    erb :'profile/edit', layout: :'layouts/main'
end 

post '/profiles/edit' do 
    redirect '/login' unless logged_in?

    # Flash message
    session[:success] = "Your Profile has been successfully updated"

    editing = true 
    @errors = editing_profile(params[:name], params[:username], params[:email], params[:password], params[:re_password], params[:country], editing: editing)

    if @errors.empty?
        update_query = "UPDATE profiles SET name = ?, username = ?, email = ?, country = ?"
        params_array = [params[:name], params[:username], params[:email], params[:country]]

        # Update password only if provided
        unless params[:password].strip.empty?
            hashed_password = BCrypt::Password.create(params[:password])
            update_query += ", password = ?"
            params_array << hashed_password
        end 

        update_query += " WHERE id = ?"
        params_array << session[:profile_id]

        DB.execute(update_query, params_array)
        redirect '/'
    else 
        @profile = {
            'name' => params[:name],
            'username' => params[:username],
            'email' => params[:email],
            'country' => params[:country]
        }

        erb :'profile/edit', layout: :'layouts/admin'
    end 
end

# Show Forgot Password Page
get '/forgot_password' do 
    @errors = []
    erb :'profile/forgot_password', layout: :'layouts/admin'
end 

# Handle Forgot Password Submission
post '/forgot_password' do 
    email = params[:email]
    @errors = []

    session[:success] = "Password reset link sent to your email."

    if email.strip.empty?
        @errors << "Email cannot be blank."
    elsif !DB.execute("SELECT * FROM  profiles WHERE email = ?", [email]).first
        @errors << "Email not found in our records."
    else 
        
        #Generate reset token (basic implementation, use a secure library in production)
        reset_token = SecureRandom.hex(20)
        DB.execute("UPDATE profiles SET reset_token = ? WHERE email = ?", [reset_token, email])

        # Simulate sending an email (in production, send a real email)
        reset_url = "http://localhost:4567/reset_password/#{reset_token}"
        puts "Reset password link: #{reset_url}" # Replace with email sending logic
        redirect '/login'
    end 

    erb :'profile/forgot_password', layout: :'layouts/admin'
end 

# Show Reset Password Page
get '/reset_password/:token' do 
    @reset_token = params[:token]
    @profile = DB.execute("SELECT * FROM profiles WHERE reset_token = ?", [@reset_token]).first

    if @profile.nil? 
        session[:error] = "Invalid or expired reset token."
        redirect '/login'
    end 

    erb :'profile/reset_password', layout: :'layouts/admin'
end 

# Handle Reset Password Submission
post '/reset_password' do 
    reset_token = params[:reset_token]
    password = params[:password]
    re_password = params[:re_password]
    @errors = []

    if password.strip.empty? || re_password.strip.empty?
        @errors << "Password fields cannot be blank."
    elsif password != re_password
        @errors << "Password do not match."
    else
        profile = DB.execute("SELECT * FROM profiles WHERE reset_token = ?", [reset_token]).first
        
        if profile.nil?
            @errors << "Invalid or expired reset token."
        else 
            hashed_password = BCrypt::Password.create(password)
            DB.execute("UPDATE profiles SET password = ?, reset_token = NULL WHERE id = ?", [hashed_password, profile['id']])
            session[:message] = "Password reset successfully. Please log in."
            redirect '/login'
        end 
    end 

    @reset_token = reset_token
    erb :'profile/reset_password', layout: :'layouts/admin'
end 

get '/cars' do 
    @title = 'List of Cars'
    @cars = DB.execute("SELECT * FROM cars")
    erb :'cars/show', layout: :'layouts/main' 
end 

get '/add' do 
    @title = 'Adding a car'
    @errors = []
    erb :'cars/add', layout: :'layouts/main'
end 

# Create a new car
post '/add' do 
    # Flash message
    session[:success] = "The Car has been successfully added."
    @errors = validate_car(params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price])

    photo = params['photo']
    @errors += validate_photo(photo) # Add photo validation errors

    photo_filename = nil

    if @errors.empty?
        # Handle file upload 
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        # Insert car details, including the photo, into the database
        DB.execute("INSERT INTO cars (name, type, brand, chair, country, manufacture, price, photo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price], photo_filename])
        redirect '/cars'
    else 
        erb :'cars/add', layout: :'layouts/main'
    end 
end 

# Form to edit a car
get '/cars/:id/edit' do 
    @title = "Edit A Car"
    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    erb :'cars/edit', layout: :'layouts/main'
end 

# Update a car
post '/cars/:id' do 
  # Flash message
  session[:success] = "Car has been successfully updated."

  # error variable check   
  @errors = validate_car(params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price], params[:id])

#   error photo variable check 
  photo = params['photo']
  @errors += validate_photo(photo) if photo && photo[:tempfile] # Validate only if a new photo is provided

  photo_filename = nil 

  if @errors.empty? 
    # Handle file upload
    if photo && photo[:tempfile]
      photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
      File.open("./public/uploads/#{photo_filename}", 'wb') do |f|
        f.write(photo[:tempfile].read)
      end 
    end 

    # Update the car in the database
    DB.execute("UPDATE cars SET name = ?, type = ?, brand = ?, chair = ?, country = ?, manufacture = ?, price = ?, photo = COALESCE(?, photo) WHERE id = ?", 
               [params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price], photo_filename, params[:id]])
    redirect '/cars'
  else 
    # Handle validation errors and re-render the edit form
    original_car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first

    # Merge user input with original data to retain user edits 
    @car = { 
      'id' => params[:id], 
      'name' => params[:name] || original_car['name'],
      'type' => params[:type] || original_car['type'],
      'brand' => params[:brand] || original_car['brand'],
      'chair' => params[:chair] || original_car['chair'], 
      'country' => params[:country] || original_car['country'],
      'manufacture' => params[:manufacture] || original_car['manufacture'],
      'price' => params[:price] || original_car['price'],
      'photo' => photo_filename || original_car['photo'],
    }
    erb :'cars/edit', layout: :'layouts/main'
  end 
end

# DELETE a car 
post '/cars/:id/delete' do
    # Flash message
    session[:success] = "Car has been successfully deleted."

    DB.execute("DELETE FROM cars WHERE id = ?", [params[:id]])
    redirect '/cars'
end

get'/motors' do 
    @title = "List of Motorcycle"
    @motors = DB.execute("SELECT * FROM motors")
    erb :'motors/index', layout: :'layouts/main'
end 

get '/adding' do 
    @title = 'Adding a motor'
    @errors = []
    erb :'motors/add', layout: :'layouts/main'
end 

# Create a new motorcycle 
post '/adding' do 
    # Flash message
    session[:success] = "Motor has been successfully added."

    @errors = validate_motor(params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price])

    # photo validation 
    photo = params['photo']
    @errors += validate_photo(photo) # Add photo validation errors
    photo_filename = nil

    # file validation
    file = params['warranty']
    @errors += validate_file(file) # Add Warranty validation errors
    file_filename = nil 

    if @errors.empty?

        # Handle photo upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end

        # Handle warranty file upload
        if file && file[:tempfile]
            file_filename = "#{Time.now.to_i}_#{file[:filename]}"
            File.open("./public/uploads/files/#{file_filename}", "wb") do |f|
                f.write(file[:tempfile].read)
            end 
        end 

        # Insert motor details, including the photo, into the database
        DB.execute("INSERT INTO motors (name, type, brand, chair, country, manufacture, price, photo, warranty) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", [params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price], photo_filename, file_filename])
        
        redirect '/motors'
    else
        erb :'motors/add', layout: :'layouts/main'
    end 
end  

# Form to edit a motor
get '/motors/:id/edit' do 
    @title = "Edit A Motor"
    @motor = DB.execute("SELECT * FROM motors WHERE id = ?", [params[:id]]).first
    @errors = []
    erb :'motors/edit', layout: :'layouts/main'
end 

# Update a motor
post '/motors/:id' do 

    # Flash message
    session[:success] = "Motor has been successfully updated."

    @errors = validate_motor(params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price], params[:id])

    # photo
    photo = params['photo']
    @errors += validate_photo(photo) if photo && photo[:tempfile] # Validate only if a new photo is provided
    photo_filename = nil 

    # file
    file = params['warranty']
    @errors += validate_file(file) if file && file[:tempfile] #validate only if a new file is provided
    file_filename = nil 


  if @errors.empty? 
    # Handle file image upload
    if photo && photo[:tempfile]
      photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
      File.open("./public/uploads/#{photo_filename}", 'wb') do |f|
        f.write(photo[:tempfile].read)
      end 
    end 

    # Handle file warranty upload
    if file && file[:tempfile]
        file_filename = "#{Time.now.to_i}_#{file[:filename]}"
        File.open("./public/uploads/files/#{file_filename}", 'wb') do |f|
            f.write(file[:tempfile].read)
        end
    end  

    # Update the car in the database
    DB.execute("UPDATE motors SET name = ?, type = ?, brand = ?, chair = ?, country = ?, manufacture = ?, price = ?, photo = COALESCE(?, photo), warranty = COALESCE(?, warranty) WHERE id = ?", 
               [params[:name], params[:type], params[:brand], params[:chair], params[:country], params[:manufacture], params[:price], photo_filename, file_filename,params[:id]])
    redirect '/motors'
  else 
    # Handle validation errors and re-render the edit form
    original_motor = DB.execute("SELECT * FROM motors WHERE id = ?", [params[:id]]).first

    # Merge user input with original data to retain user edits 
    @motor = { 
      'id' => params[:id], 
      'name' => params[:name] || original_motor['name'],
      'type' => params[:type] || original_motor['type'],
      'brand' => params[:brand] || original_motor['brand'],
      'chair' => params[:chair] || original_motor['chair'], 
      'country' => params[:country] || original_motor['country'],
      'manufacture' => params[:manufacture] || original_motor['manufacture'],
      'price' => params[:price] || original_motor['price'],
      'photo' => photo_filename || original_motor['photo'],
      'warranty' => file_filename || original_motor['warranty']
    }
    erb :'motors/edit', layout: :'layouts/main'
  end 
end

# Delete a motor
post '/motors/:id/delete' do 
    # Flash message
    session[:success] = "Motor has been successfully deleted."

    # Delete logic
    DB.execute("DELETE FROM motors WHERE id = ?", [params[:id]])

    redirect '/motors'
end 

get '/leafs' do 
    @title = 'Leaf'
    @leafs = DB.execute("SELECT * FROM leafs")
    erb :'trees/leafs/index', layout: :'layouts/main'
end 

# Form to add a leaf
get '/add_leaf' do 
    @title = 'Add A Leaf'
    @errors = []
    erb :'trees/leafs/add', layout: :'layouts/main'
end

# adding a leaf
post '/adding_leaf' do 
    @errors = validate_leaf(params[:name], params[:type], params[:age], params[:description])

    if @errors.empty?

        # Flash message
        session[:success] = "A Seed has been successfully added."

        # Insert seed details into the database
        DB.execute("INSERT INTO leafs (name, type, age, description) VALUES (?, ?, ?, ?)", [params[:name], params[:type], params[:age], params[:description]])
        redirect '/leafs'
    else 
        erb :'trees/leafs/add', layout: :'layouts/main'
    end 
end 

# Form to edit a leaf 
get '/leafs/:id/edit' do 
    @title = "Edit A leaf"
    @leaf = DB.execute("SELECT * FROM leafs WHERE id = ?", [params[:id]]).first
    @errors = []
    erb :'trees/leafs/edit', layout: :'layouts/main'
end 

# Update a leaf
post '/leafs/:id' do 
    @errors = validate_leaf(params[:name], params[:type], params[:age], params[:description], params[:id])

    if @errors.empty? 

        # Flash Message
        session[:success] = "A Leaf has been successfully updated."
        # Update the leaf in the database
        DB.execute("UPDATE leafs SET name = ?, type = ?, age = ?, description = ? WHERE id = ?", [params[:name], params[:type], params[:age], params[:description], params[:id]])

        redirect '/leafs'
    else 
        # Handle validation errors and re-render the edit form
        original_leaf = DB.execute("SELECT * FROM leafs WHERE id = ?", [params[:id]]).first

        @leaf = {
            'id' => params[:id],
            'name' => params[:name] || original_leaf['name'],
            'type' => params[:type] || original_leaf['type'],
            'age' => params[:age] || original_leaf['age'],
            'description' => params[:description] || original_leaf['description']
        }
        erb :'trees/leafs/edit', layout: :'layouts/main'
    end 
end 

# Delete a leaf
post '/leafs/:id/delete' do 
    # Flash message
    session[:success] = "A Seed has been successfully deleted."

    DB.execute("DELETE FROM leafs WHERE id = ?", [params[:id]])
    redirect '/leafs'
end 

get '/seeds' do 
    @title = 'Seed'
    @seeds = DB.execute("SELECT * FROM seeds")
    erb :'trees/seeds/index', layout: :'layouts/main'
end 

get '/add_seed' do 
    @title = 'Add A Seed'
    @errors = []
    erb :'trees/seeds/add', layout: :'layouts/main'
end 

post '/adding_seed' do 
    @errors = validate_seed(params[:name])

    if @errors.empty? 

        # Flash message
        session[:success] = "A Seed has been successfully added."

        # Insert seed details into the database
        DB.execute("INSERT INTO seeds (name) VALUES (?)", [params[:name]])
        redirect '/seeds'
    else 
        erb :'trees/seeds/add', layout: :'layouts/main'
    end 
end 

# Form to edit a seed
get '/seeds/:id/edit' do 
    @title = "Edit A seed"
    @seed = DB.execute("SELECT * FROM seeds WHERE id = ?", [params[:id]]).first 
    @errors = []
    erb :'trees/seeds/edit', layout: :'layouts/main'
end 

# Update a seed
post '/seeds/:id' do 
    # Flash message
    session[:success] = "A Seed has been successfully updated."
    @errors = validate_seed(params[:name], params[:id])

    if @errors.empty?
        # Update the car in the database
        DB.execute("UPDATE seeds SET name = ? WHERE id = ?", 
            [params[:name], params[:id]])
        redirect '/seeds'
    else 
        # Handle validation errors and re-render the edit form
        original_seed = DB.execute("SELECT * FROM seeds WHERE id = ?", [params[:id]]).first
        # Merge seeds input withg original data to retain seed edits 
        @seed = {
            'id' => params[:id],
            'name' => params[:name] || original_seed['name']
        }
        erb :'trees/seeds/edit', layout: :'layouts/main'
    end 
end

# DELETE a Seed
post '/seeds/:id/delete' do 
    # Flash message
    session[:success] = "A Seed has been successfully deleted."

    DB.execute("DELETE FROM seeds WHERE id = ?", [params[:id]])
    redirect '/seeds'
end 

get '/trees' do 
    @title = 'Trees List'
    @trees = DB.execute("Select * FROM trees")
    erb :'trees/index', layout: :'layouts/main'
end 

get '/add_tree' do 
    @title = "Add A Tree"
    @errors = []
    erb :'trees/add', layout: :'layouts/main'
end 

# Create a new tree
post '/adding_tree' do 

    # Validate the input
    @errors = validate_tree(
        params[:name], 
        params[:type], 
        params[:leaf_id], 
        params[:seed_id],
        params[:age], 
        params[:description]
    )

    # If there are errors,re-render the form
    if @errors.empty?
        # insert the new tree into the database
        DB.execute(
            "INSERT INTO trees (name, type, leaf_id, seed_id, age, description) VALUES (?, ?, ?, ?, ?, ?)",
            [
                params[:name],
                params[:type],
                params[:leaf_id].to_i,
                params[:seed_id].to_i,
                params[:age].to_i,
                params[:description]
            ]
        )
        
        # Flash message
        session[:success] = "The Tree has been successfully added."
        redirect '/trees'
    else
        # Render the form with errors and current input values
        @title = 'Adding a Tree'
        erb :'trees/add', layout: :'layouts/main'
    end 
end 

# GET: Render the edit form for a tree
get '/trees/:id/edit' do 
    @title = "Edit A Tree"

    # Fetch the tree data by ID
    @tree = DB.get_first_row("SELECT * FROM trees WHERE id = ?", [params[:id]])
    halt 404, "Tree not found" unless @tree

    # Fetch data from dropdowns
    @leafs = DB.execute("SELECT id, name FROM leafs") || []
    @seeds = DB.execute("SELECT id, name FROM seeds") || []

    @errors = []
    erb :'trees/edit', layout: :'layouts/main'
end 

# update a tree
post '/trees/:id' do 

    # Validate input
    @errors = validate_tree(params[:name], params[:type], params[:leaf_id], params[:seed_id], params[:age], params[:description], params[:id])

    if @errors.empty?
        # Update the tree in the database
        DB.execute(
            "UPDATE trees SET name = ?, type = ?, leaf_id = ?, seed_id = ?, age = ?, description = ? WHERE id = ?",
            [params[:name], params[:type], params[:leaf_id].to_i, params[:seed_id].to_i, params[:age].to_i, params[:description], params[:id]]
        )

        # Flash success message and redirect
        session[:success] = "The Tree has been successfully updated."
        redirect '/trees'
    else 
        # Handle validation errors and re-render the edit form
        original_tree = DB.execute("SELECT * FROM trees WHERE id = ?", [params[:id]])

        # Merge user input with original data to retain user edits
        @tree = {
            'id' => params[:id],
            'name' => params[:name] || original_tree['name'],
            'type' => params[:type] || original_tree['type'],
            'leaf_id' => params[:leaf_id] || original_tree['leaf_id'],
            'seed_id' => params[:seed_id] || original_tree['seed_id'],
            'age' => params[:age] || original_tree['age'],
            'description' => params[:description] || original_tree['description']
        }

        # Fetch leafs and seeds for dropdowns
        @leafs = DB.execute("SELECT id, name FROM leafs") || []
        @seeds = DB.execute("SELECT id, name FROM seeds") || []

        erb :'trees/edit', layout: :'layouts/main'
    end 
end 

# Delete a tree
post '/trees/:id/delete' do 
    # Flash message
    session[:success] = "A Seed has been successfully deleted."

    DB.execute("DELETE FROM trees WHERE id = ?", [params[:id]])
    redirect '/trees'
end 