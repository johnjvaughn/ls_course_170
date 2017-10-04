ENV['RACK_ENV'] = 'test'

require "minitest/autorun"
require "rack/test"

require_relative "../recipes.rb"

class RecipesTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(dir_path_to('data'))
  end

  def teardown
    FileUtils.rm_rf(dir_path_to('data'))
  end

  def test_index_page
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Recipe Book"
    assert_includes last_response.body, "Sign In"

    get "/", {}, {"rack.session" => { username: "admin"} }
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "Sign Out"
  end

end
