require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, escape_html: true
end

def data_path
  dir_path = ENV["RACK_ENV"] == "test" ? "../test/data" : "../data"
  File.expand_path(dir_path, __FILE__)
end

def full_data_path(basename)
  File.join(data_path, basename)
end

def data_files
  Dir.glob(full_data_path("*")).map { |path| File.basename(path) }
end

def message_and_redirect(message, redirect_to = "/")
  session[:message] = message
  redirect redirect_to if redirect_to
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
    headers['Content-Type'] = 'text/plain'
    content
  end
end

def content_raw(path)
  unless File.file?(path)
    message_and_redirect("#{File.basename(path)} does not exist.")
  end
  File.read(path)
end

get "/" do
  # return erb :signin unless session[:username]
  @files = data_files
  erb :index
end

get "/new" do
  erb :new
end

post "/create" do
  new_file_name = params[:new_file_name].strip
  if new_file_name.empty?
    session[:message] = "A name is required."
    status 422
    return erb :new
  end
  new_file_path = full_data_path(new_file_name)
  if File.exist?(new_file_path)
    session[:message] = "That file already exists."
    status 422
    return erb :new
  end
  File.write(new_file_path, '')
  message_and_redirect("#{new_file_name} was created.")
end

get "/:file" do
  content_by_type(full_data_path(params[:file]))
end

get "/:file/edit" do
  @content = content_raw(full_data_path(params[:file]))
  erb :edit
end

post "/:file" do
  File.write(full_data_path(params[:file]), params[:file_content])
  message_and_redirect("#{params[:file]} has been updated.")
end

post "/:file/destroy" do
  File.delete(full_data_path(params[:file]))
  message_and_redirect("#{params[:file]} was deleted.")
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  unless params[:username] == 'admin' && params[:password] == 'secret'
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
