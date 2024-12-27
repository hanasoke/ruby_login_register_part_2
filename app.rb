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
    errors << "Email cannot be blank." if email.nil? || email.strip.empty?
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
        # check if email matches the regular expressionj
        errors << "Email format is invalid"
    end

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
    erb :forgot_password, layout: :'layouts/main'
end 

# Handle Forgot Password Submission
post '/forgot_password' do 
    email = params[:email]
    @errors = []

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
        session[:message] = "Password reset link sent to your email."
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

    erb :reset_password, layout: :'layouts/admin'
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
    erb :reset_password, layout: :'layouts/admin'
end 
        