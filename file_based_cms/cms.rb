require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, escape_html: true
end

ROOT = File.expand_path("..", __FILE__)

def data_files
  Dir.glob(ROOT + "/data/*").map { |path| File.basename(path) }
end

get "/" do
  @files = data_files
  erb :index
end

get "/:file" do
  full_path = ROOT + "/data/" + params[:file]
  if File.file?(full_path)
    content = File.read(full_path)
    case File.extname(full_path)
    when ".md"
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      markdown.render(content)
    else
      headers['Content-Type'] = 'text/plain'
      content
    end
  else
    session[:error] = "#{params[:file]} does not exist."
    redirect "/"
  end
end


