require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
end

helpers do
  def list_complete?(list)
    !list[:todos].empty? && num_todos_remaining(list) == 0
  end

  def list_class(list)
    if list[:todos].empty?
      "new"
    elsif list_complete?(list)
      "complete"
    else
      ""
    end
  end

  def num_todos_remaining(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def num_todos(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = 
      lists.partition { |list| list_complete?(list) }
    incomplete_lists.each { |list| yield list, lists.index(list)}
    complete_lists.each { |list| yield list, lists.index(list)}
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = 
      todos.partition { |todo| todo[:completed] }
    incomplete_todos.each { |todo| yield todo, todos.index(todo)}
    complete_todos.each { |todo| yield todo, todos.index(todo)}
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists
end

# Render the new list form
get "/lists/new" do
  erb :new_list
end

def error_for_list_name(name)
  # return an error message if name is not a valid list name
  # if all good, return nil
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

def error_for_todo_name(name)
  # return an error message if name is not a valid todo name
  # if all good, return nil
  if !(1..100).cover?(name.size)
    "Todo name must be between 1 and 100 characters."
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    return erb :new_list
  end
  session[:lists] << { name: list_name, todos: [] }
  session[:success] = "This list has been created."
  redirect "/lists"
end

def valid_list_id?(id)
  (0...session[:lists].count).cover?(id)
end

def valid_todo_id?(list_id, todo_id)
  (0...session[:lists][list_id][:todos].count).cover?(todo_id)
end

# Show one list
get "/lists/:id" do
  @list_id = params[:id].to_i
  redirect "/lists" unless valid_list_id?(@list_id)
  @list = session[:lists][@list_id]
  erb :list
end

# Render the edit list form
get "/lists/:id/edit" do
  id = params[:id].to_i
  redirect "/lists" unless valid_list_id?(id)
  @list = session[:lists][id]
  erb :edit_list
end

# Update the existing, edited list
post "/lists/:id" do
  id = params[:id].to_i
  redirect "/lists" unless valid_list_id?(id)
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    @list = session[:lists][id]
    return erb :edit_list
  end
  session[:lists][id][:name] = list_name
  session[:success] = "This list has been updated."
  redirect "/lists/#{id}"
end

post "/lists/:id/destroy" do
  id = params[:id].to_i
  redirect "/lists" unless valid_list_id?(id)
  @deleted_list = session[:lists].delete_at(id)
  session[:success] = "The list '#{@deleted_list[:name]}' has been deleted."
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  redirect "/lists" unless valid_list_id?(@list_id)
  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    @list = session[:lists][@list_id]
    return erb :list
  end
  redirect "/lists" unless valid_list_id?(@list_id)
  session[:lists][@list_id][:todos] << { name: todo_name, completed: false }
  session[:success] = "The todo has been added."
  redirect "/lists/#{@list_id}"
end

post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  redirect "/lists" unless valid_list_id?(@list_id)
  todo_id = params[:todo_id].to_i
  redirect "/lists/#{@list_id}" unless valid_todo_id?(@list_id, todo_id)
  @deleted_todo = session[:lists][@list_id][:todos].delete_at(todo_id)
  session[:success] = "The todo '#{@deleted_todo[:name]}' has been deleted."
  redirect "/lists/#{@list_id}"
end

post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  redirect "/lists" unless valid_list_id?(@list_id)
  todo_id = params[:todo_id].to_i
  redirect "/lists/#{@list_id}" unless valid_todo_id?(@list_id, todo_id)
  todo = session[:lists][@list_id][:todos][todo_id]
  todo[:completed] = (params[:completed] == 'true')
  session[:success] = "The todo '#{todo[:name]}' has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all the todos on the list completed
post "/lists/:id/complete_all" do
  id = params[:id].to_i
  redirect "/lists" unless valid_list_id?(id)
  session[:lists][id][:todos].map! { |todo| { name: todo[:name], completed: true } }
  session[:success] = "All todos on this list have been completed."
  redirect "/lists/#{id}"
end