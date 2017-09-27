require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, escape_html: true
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
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos =
      todos.partition { |todo| todo[:completed] }
    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

# return an error message if name is not a valid list name
# if all good, return nil
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# return an error message if name is not a valid todo name
# if all good, return nil
def error_for_todo_name(name)
  if !(1..100).cover?(name.size)
    "Todo name must be between 1 and 100 characters."
  end
end

def load_list(id)
  session[:lists].each do |list|
    return list if list[:id] == id
  end
  session[:error] = "The specified list was not found."
  redirect "/lists"
end

def load_todo(list_id, todo_id)
  list = load_list(list_id)
  list[:todos].each do |todo|
    return todo if todo[:id] == todo_id
  end
  session[:error] = "The specified todo was not found."
  redirect "/lists/#{list_id}"
end

def next_item_id(items)
  max = items.map { |item| item[:id] }.max || 0
  max + 1
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

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    return erb :new_list
  end
  id = next_item_id(session[:lists])
  session[:lists] << { id: id, name: list_name, todos: [] }
  session[:success] = "This list has been created."
  redirect "/lists"
end

# Show one list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list
end

# Render the edit list form
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list
end

# Update the existing, edited list
post "/lists/:id" do
  id = params[:id].to_i
  @list = load_list(id)
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    return erb :edit_list
  end
  @list[:name] = list_name
  session[:success] = "This list has been updated."
  redirect "/lists/#{id}"
end

# Delete a list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  list = load_list(id)
  session[:lists].delete(list)
  if env['HTTP_X_REQUESTED_WITH'] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list '#{list[:name]}' has been deleted."
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    return erb :list
  end
  todo_id = next_item_id(@list[:todos])
  @list[:todos] << { id: todo_id, name: todo_name, completed: false }
  session[:success] = "The todo has been added."
  redirect "/lists/#{@list_id}"
end

# Delete a todo
post "/lists/:list_id/todos/:todo_id/destroy" do
  list_id = params[:list_id].to_i
  list = load_list(list_id)
  todo_id = params[:todo_id].to_i
  todo = load_todo(list_id, todo_id)
  list[:todos].delete(todo)
  if env['HTTP_X_REQUESTED_WITH'] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo '#{todo[:name]}' has been deleted."
    redirect "/lists/#{list_id}"
  end
end

# Mark a todo as completed or un-completed
post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todo = load_todo(list_id, todo_id)
  todo[:completed] = (params[:completed] == 'true')
  session[:success] = "The todo '#{todo[:name]}' has been updated."
  redirect "/lists/#{list_id}"
end

# Mark all the todos on the list completed
post "/lists/:id/complete_all" do
  id = params[:id].to_i
  list = load_list(id)
  list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos on this list have been completed."
  redirect "/lists/#{id}"
end
