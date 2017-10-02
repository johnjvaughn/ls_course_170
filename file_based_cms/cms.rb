require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, escape_html: true
end

ALLOWED_EXTS = ['.md', '.txt']

def dir_path_to(subdir = '')
  dir_path = ENV["RACK_ENV"] == "test" ? "../test/#{subdir}" : "../#{subdir}"
  dir_path.chomp!('/')
  File.expand_path(dir_path, __FILE__)
end

def full_path_to(basename, subdir = '')
  File.join(dir_path_to(subdir), basename)
end

def data_files
  files = Dir.glob(full_path_to("*", 'data')).map { |path| File.basename(path) }
  files.select { |file| valid_filename?(file) }
end

def message_and_redirect(message, redirect_to = "/")
  session[:message] = message
  redirect redirect_to if redirect_to
end

def redirect_if_not_signed_in
  return if session.key?(:username)
  message_and_redirect("You must be signed in to do that.")
end

def validate_user(username, password)
  user_data = YAML.load_file(full_path_to('users.yml'))
  return false unless user_data[username]
  bcrypt_pass = BCrypt::Password.new(user_data[username])
  bcrypt_pass == password
end

def valid_filename?(filename)
  ALLOWED_EXTS.include?(File.extname(filename).downcase)
end

def redirect_if_not_valid_filename(filename)
  unless (valid_filename?(filename))
    message_and_redirect("File name is invalid.")
  end
end

def content_by_type(path)
  unless File.file?(path)
    message_and_redirect("#{File.basename(path)} does not exist.")
  end
  content = File.read(path)

  case File.extname(path).downcase
  when ".md"
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    erb markdown.render(content)
  else
    if ALLOWED_EXTS.include?(File.extname(path).downcase)
      headers['Content-Type'] = 'text/plain'
      content
    end
  end
end

def content_raw(path)
  unless File.file?(path)
    message_and_redirect("#{File.basename(path)} does not exist.")
  end
  File.read(path)
end

get "/" do
  @files = data_files
  erb :index
end

get "/new" do
  redirect_if_not_signed_in
  if ALLOWED_EXTS.count > 1
    @exts_allowed = ALLOWED_EXTS[0..-2].join(', ') + ' or ' + ALLOWED_EXTS.last
  else 
    @exts_allowed = ALLOWED_EXTS.first
  end
  erb :new
end

post "/create" do
  redirect_if_not_signed_in
  new_file_name = params[:new_file_name].strip
  if new_file_name.empty?
    session[:message] = "A name is required."
    status 422
    return erb :new
  end
  unless valid_filename?(new_file_name)
    session[:message] = "Files with that extension are not allowed."
    status 422
    return erb :new
  end
  new_file_path = full_path_to(new_file_name, 'data')
  if File.exist?(new_file_path)
    session[:message] = "That file already exists."
    status 422
    return erb :new
  end
  File.write(new_file_path, '')
  message_and_redirect("#{new_file_name} was created.")
end

get "/:file" do
  redirect_if_not_valid_filename(params[:file])
  content_by_type(full_path_to(params[:file], 'data'))
end

get "/:file/edit" do
  redirect_if_not_signed_in
  redirect_if_not_valid_filename(params[:file])
  @content = content_raw(full_path_to(params[:file], 'data'))
  erb :edit
end

post "/:file" do
  redirect_if_not_signed_in
  redirect_if_not_valid_filename(params[:file])
  File.write(full_path_to(params[:file], 'data'), params[:file_content])
  message_and_redirect("#{params[:file]} has been updated.")
end

post "/:file/destroy" do
  redirect_if_not_signed_in
  redirect_if_not_valid_filename(params[:file])
  File.delete(full_path_to(params[:file], 'data'))
  message_and_redirect("#{params[:file]} was deleted.")
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
  message_and_redirect("Welcome!")
end

post "/users/signout" do
  session.delete(:username)
  message_and_redirect("You have been signed out.")
end
