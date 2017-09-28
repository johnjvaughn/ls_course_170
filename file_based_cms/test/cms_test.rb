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
    File.open(full_path(name), 'w') do |file|
      file.write(content)
    end
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_index
    create_document("about.md")
    create_document("changes.txt")

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<a href='/about.md'>about.md</a>"
    assert_includes last_response.body, "<a href='/about.md/edit'>edit</a>"
    assert_includes last_response.body, "<a href='/changes.txt'>changes.txt</a>"
    assert_includes last_response.body, "<a href='/changes.txt/edit'>edit</a>"
  end

  def test_history_file
    create_document("history.txt", "testing content")

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal "testing content", last_response.body
  end

  def test_non_existent_file
    get "/doesnot.exist"
    assert_equal 302, last_response.status
    get last_response['location']
    assert_includes last_response.body, "doesnot.exist does not exist."
    get "/"
    refute_includes last_response.body, "does not exist."
  end

  def test_markdown_file
    create_document("about.md", "#About Markdown\n")

    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>About Markdown</h1>"
  end

  def test_edit_file
    create_document("about.txt", "testing editing")
    get "/about.txt/edit"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea>testing editing</textarea>"
    assert_includes last_response.body, "<button type='submit'"
  end

  def test_update_file
    create_document("about.txt", "testing updating")

    post "/about.txt", file_content: "new content after updating"
    assert_equal 302, last_response.status
    get last_response['location']
    assert_includes last_response.body, "about.txt has been updated"

    get "/about.txt"
    assert_equal 200, last_response.status
    assert_equal last_response.body, "new content after updating"
  end
end
