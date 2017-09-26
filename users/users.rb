require "tilt/erubis"
require "sinatra"
require "sinatra/reloader"
require "yaml"

before do
  @user_data = YAML.load_file('data/users.yaml')
end

helpers do
  def count_interests
    @user_data.sum { |user, hash| hash[:interests].count }
  end
end

get "/users" do
  @name = nil
  erb :users
end

get "/users/:name" do
  @name = params[:name]
  erb :user
end

get "/" do
  redirect "/users"
end

not_found do
  redirect "/users"
end
