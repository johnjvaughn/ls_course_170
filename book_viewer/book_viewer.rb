require "tilt/erubis"
require "sinatra"
require "sinatra/reloader"

before do
  @book_title = "The Adventures of Sherlock Holmes"
  @toc = File.readlines("data/toc.txt")
end

helpers do
  def in_paragraphs(text)
    text.split("\n\n").map.with_index do |pgraph, index|
      "<p id='p#{index + 1}'>#{pgraph}</p>"
    end.join("\n\n")
  end

  def highlight(text, term)
    text.gsub(term, "<strong>#{term}</strong>")
  end
end

get "/" do
  @page_title = @book_title
  erb :home
end

def chapter_content(chap_num)
  File.read("data/chp#{chap_num}.txt")
end

get "/chapters/:number" do
  number = params[:number].to_i
  redirect "/" unless (1..@toc.size).cover?(number)
  chap_name = @toc[number - 1]
  @chap_title = "Chapter #{number}: #{chap_name}"
  @page_title = @chap_title
  @content = chapter_content(number)
  erb :chapter
end

def find_query_matches(chap_num)
  content = chapter_content(chap_num)
  pgraph_matches = {}
  return pgraph_matches unless content.match?(/#{@query}/i)
  content.split("\n\n").each_with_index do |pgraph, index|
    pgraph_matches[index + 1] = pgraph if pgraph.match?(/#{@query}/i)
  end
  pgraph_matches
end

get "/search" do
  @query = params['query']
  unless @query.nil? || @query.empty?
    @results = []
    @toc.each_with_index do |chap_name, index|
      pgraphs = find_query_matches(index + 1)
      next if pgraphs.empty?
      @results << { chap_name: chap_name, chap_num: "#{index + 1}", pgraphs: pgraphs }
    end
  end
  erb :search
end

not_found do
  redirect "/"
end
