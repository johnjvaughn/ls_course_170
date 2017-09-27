require "tilt/erubis"
require "sinatra"
require "sinatra/reloader"
require "yaml"

configure do
  enable :sessions
  set :session_secret, "NraGu4DABR5m4OrZkarHKfONYXlC1a0tTpu2BXBpalFksQuYCeF5SQKl2fVuwAQL"
end

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
