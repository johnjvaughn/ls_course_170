require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, escape_html: true
end

before do
  session[:secret_number] = rand(3) + 1
  session[:balance] = 100 unless session.key?(:balance)
end

def decide_bet(guess, bet)
  if guess == session[:secret_number]
    session[:balance] += bet
    session[:message] = "You have guessed correctly."
  else
    session[:balance] -= bet
    redirect "/broke" if session[:balance] <= 0
    session[:message] = "You guessed #{guess}, but the number was" \
                        " #{session[:secret_number]}."
  end
end

def broke?
  session[:balance] < 1
end

get "/" do
  redirect "/broke" if broke?
  erb :guess
end

post "/" do
  session[:balance] = 100 if broke?
  erb :guess
end

post "/guess" do
  guess = params[:guess].to_i
  bet = params[:bet].strip.delete('$').to_i
  unless (1..session[:balance]).cover?(bet)
    session[:message] = "Bets must be between $1 and $#{session[:balance]}."
    return erb :guess
  end
  decide_bet(guess, bet)
  redirect "/"
end

get "/broke" do
  redirect "/" unless broke?
  session[:message] = "You have lost all your money."
  erb :broke
end

not_found do
  redirect "/"
end
