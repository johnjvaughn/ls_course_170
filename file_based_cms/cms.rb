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
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def full_path(basename)
  File.join(data_path, basename)
end

def data_files
  pattern = File.join(data_path, "*")
  Dir.glob(pattern).map { |path| File.basename(path) }
end

def message_and_redirect(message, redirect_to = "/")
  session[:message] = message
  redirect redirect_to
end

def content_by_type(path)
  unless File.file?(path)
    message_and_redirect("#{File.basename(path)} does NOT exist.")
  end
  content = File.read(path)

  case File.extname(path)
  when ".md"
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(content)
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
  @files = data_files
  erb :index
end

get "/:file" do
  return nil if params[:file] == 'favicon.ico'
  content_by_type(full_path(params[:file]))
end

get "/:file/edit" do
  @content = content_raw(full_path(params[:file]))
  erb :edit
end

post "/:file" do
  File.write(full_path(params[:file]), params[:file_content])
  message_and_redirect("#{params[:file]} has been updated.")
end

