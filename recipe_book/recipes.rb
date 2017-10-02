require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, escape_html: true
end

RECIPE_CATEGORIES ||= ['breakfast', 'lunch', 'dinner', 'snack', 'dessert',
                     'drink'].freeze
RECIPE_KEYS ||= [:id, :name, :ingredients, :instructions, :category, :cuisine,
               :image, :public]

def dir_path_to(subdir = '')
  dir_path = ENV["RACK_ENV"] == "test" ? "../test/#{subdir}" : "../#{subdir}"
  dir_path.chomp!('/')
  File.expand_path(dir_path, __FILE__)
end

def full_path_to(basename, subdir = '')
  File.join(dir_path_to(subdir), basename)
end

def validate_user(username, password)
  user_data = YAML.load_file(full_path_to('users.yml'))
  return false unless user_data[username]
  bcrypt_pass = BCrypt::Password.new(user_data[username])
  bcrypt_pass == password
end

def record_new_user(username, password)
  bcrypt_pass = BCrypt::Password.create(password).to_s
  user_data = YAML.load_file(full_path_to('users.yml'))
  if user_data.key?(username)
    message_and_redirect("That username is already in use.", "/users/register")
  end
  user_data[username] = bcrypt_pass
  File.open(full_path_to('users.yml'), 'w') do |file|
    YAML.dump(user_data, file)
  end
end

def validate_registration(username, password1, password2)
  if password1 != password2
    session[:message] = "Passwords do not match."
    return false
  elsif username.empty?
    session[:message] = "Username is required."
    return false
  elsif password1.length < 6
    session[:message] = "Password must be at least 6 characters."
    return false
  elsif username.match?(/\s/) || password1.match?(/\s/)
    session[:message] = "Username and password must not contain whitespace."
    return false
  end
  true
end

def message_and_redirect(message, redirect_to = "/")
  session[:message] = message
  redirect redirect_to if redirect_to
end

def redirect_if_not_signed_in
  return if session.key?(:username)
  message_and_redirect("You must be signed in to do that.", "/users/signin")
end

def unique_recipe_id(recipes)
  max = recipes.map { |recipe| recipe[:id] }.max || 0
  max + 1
end

def find_recipe(id)
  recipes = session[:recipes] || []
  recipes.find { |recipe| recipe[:id] == id.to_i }
end

def save_recipe(recipe)
  RECIPE_KEYS.each do |key|
    recipe[key] = if key == :id
                    params[key].to_i
                  elsif key == :public
                    (params[:public] == 'true')
                  else
                    params[key]
                  end
  end
  unless recipe[:id]
    recipes = session[:recipes] || []
    recipe[:id] = unique_recipe_id(recipes)
  end
  recipe
end

def save_recipes_to_file
  return unless session.key?(:username) && session.key?(:recipes)
  filename = session[:username] + ".yml"
  File.open(full_path_to(filename, 'data'), 'w') do |file|
    YAML.dump(session[:recipes], file)
  end
end

def load_recipes_from_file
  return unless session.key?(:username)
  filename = session[:username] + ".yml"
  if File.exist?(full_path_to(filename, 'data'))
    session[:recipes] = YAML.load_file(full_path_to(filename, 'data'))
  end
end

def load_public_recipes
  files = Dir.glob(full_path_to("*.yml", 'data')).map do |path|
    File.basename(path)
  end
  public_recipes = []
  files.each do |filename|
    public_recipes += YAML.load_file(full_path_to(filename, 'data'))
  end
  public_recipes.select { |recipe| recipe[:public] }
end

get "/" do
  if session.key?(:username)
    @recipes = session[:recipes] || []
    @recipes.sort! { |a, b| a[:name] <=> b[:name] }
  end
  erb :index
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  unless validate_user(params[:username], params[:password])
    session[:message] = "Invalid credentials."
    status 422
    return erb :signin
  end
  session[:username] = params[:username]
  load_recipes_from_file
  message_and_redirect("Welcome #{session[:username]}!")
end

post "/users/signout" do
  session.delete(:username)
  session.delete(:recipes)
  message_and_redirect("You have been signed out.")
end

get "/users/register" do
  erb :register
end

post "/users/register" do
  if validate_registration(params[:username], params[:password],
                           params[:password2])
    session[:username] = params[:username]
    record_new_user(session[:username], params[:password])
    message_and_redirect("Welcome #{session[:username]}!")
  else
    erb :register
  end
end

get "/recipes/new" do
  redirect_if_not_signed_in
  erb :new_recipe
end

post "/recipes/create" do
  redirect_if_not_signed_in
  if params[:name].empty?
    message_and_redirect("Name is required.", "/recipes/new")
  end
  session[:recipes] ||= []
  new_recipe = {}
  save_recipe(new_recipe)
  session[:recipes] << new_recipe
  save_recipes_to_file
  message_and_redirect("Recipe added successfully.")
end

get "/recipes/:id" do
  @recipe = find_recipe(params[:id])
  message_and_redirect("Recipe not found.") unless @recipe
  erb :recipe
end

get "/recipes/:id/edit" do
  @recipe = find_recipe(params[:id])
  message_and_redirect("Recipe not found.") unless @recipe
  erb :edit_recipe
end

post "/recipes/:id/update" do
  @recipe = find_recipe(params[:id])
  message_and_redirect("Recipe not found.") unless @recipe
  save_recipe(@recipe)
  save_recipes_to_file
  erb :recipe
end

post "/recipes/:id/destroy" do
  recipe = find_recipe(params[:id])
  message_and_redirect("Recipe not found.") unless recipe
  session[:recipes].delete(recipe)
  message_and_redirect("Recipe deleted.")
end

get "/public_recipes" do
  @public_recipes = load_public_recipes
  erb :public_recipes
end
