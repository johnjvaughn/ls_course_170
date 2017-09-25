require "tilt/erubis"
require "sinatra"
require "sinatra/reloader"

get "/" do
  @files = Dir.glob("public/*").map {|file| File.basename(file) }.sort
  @files.reverse! if params[:sort] == 'desc'
  @title = "Public Files"
  erb :file_listing
end

