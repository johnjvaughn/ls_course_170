ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def create_document(name, content = '')
    File.open(full_data_path(name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_index_unsigned
    create_document("changes.txt")

    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "/users/signin"
    assert_includes last_response.body, "Sign In"
    assert_includes last_response.body, "changes.txt"
  end

  def test_index_signed
    create_document("about.md")
    create_document("changes.txt")

    get "/", {}, {"rack.session" => { username: "admin"} }
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<a href='/about.md'>about.md</a>"
    assert_includes last_response.body, "<a href='/about.md/edit'>edit</a>"
    assert_includes last_response.body, "<a href='/changes.txt'>changes.txt</a>"
    assert_includes last_response.body, "<a href='/changes.txt/edit'>edit</a>"
    assert_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "Sign Out"
  end

  def test_view_text_file
    create_document("history.txt", "testing content")

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal "testing content", last_response.body
  end

  def test_view_markdown_file
    create_document("about.md", "#About Markdown\n")

    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>About Markdown</h1>"
  end

  def test_non_existent_file
    get "/doesnot.exist"
    assert_equal 302, last_response.status
    assert_equal "doesnot.exist does not exist.", session[:message]

    get "/", {}, {"rack.session" => { username: "admin"} }
    assert_nil session[:message]
  end

  def test_edit_file
    create_document("about.txt", "testing editing")
    
    get "/about.txt/edit"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "testing editing"
    assert_includes last_response.body, "<button type='submit'"
  end

  def test_update_file
    create_document("about.txt", "testing updating")

    post "/about.txt", file_content: "new content after updating"
    assert_equal 302, last_response.status
    assert_equal "about.txt has been updated.", session[:message]

    get "/about.txt"
    assert_equal 200, last_response.status
    assert_equal "new content after updating", last_response.body
  end

  def test_new_file_form
    get "/new"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "<button type='submit'"
  end

  def test_create_file_success
    post "/create", new_file_name: 'testing_new.txt'
    assert_equal 302, last_response.status
    assert_equal "testing_new.txt was created.", session[:message]
    
    get last_response['location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, "href='/testing_new.txt'"
    assert_nil session[:message]
  end

  def test_create_file_fails
    post "/create", new_file_name: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, "name is required"

    create_document("testing_new.txt")
    post "/create", new_file_name: 'testing_new.txt'
    assert_equal 422, last_response.status
    assert_includes last_response.body, "file already exists"
  end

  def test_delete_file
    create_document("testing_new.txt")

    post "/testing_new.txt/destroy"
    assert_equal 302, last_response.status
    assert_equal "testing_new.txt was deleted.", session[:message]

    get last_response['location']
    assert_equal 200, last_response.status
    refute_includes last_response.body, "href='/testing_new.txt'"
    assert_nil session[:message]
  end

  def test_signin_form
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "<button type='submit"
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
    assert_nil session[:message]
  end

  def test_signin_fail
    post "/users/signin", username: "bad", password: "bad"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Sign In"
    assert_includes last_response.body, "Invalid credentials"
    assert_nil session[:username]
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin"} }
    assert_equal "admin", session[:username]
    
    post "/users/signout"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]
    assert_nil session[:username]
    
    get last_response["Location"]
    assert_includes last_response.body, "Sign In"
    assert_nil session[:message]
  end
end
