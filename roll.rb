require "socket"

def parse_request(request_line)
  # i.e. GET /?rolls=2&sides=6 HTTP/1.1
  http_method, path_and_query, http = request_line.split
  path, query = path_and_query.split('?')
  params = nil
  if query
    params = query.split('&').each_with_object({}) do |pair_str, hash|
      key, value = pair_str.split('=')
      hash[key] = value
    end
  end
  [http_method, path, params, http]
end

server = TCPServer.new("localhost", 3003)
loop do
  client = server.accept

  request_line = client.gets
  next if !request_line || request_line =~ /favicon/
  puts request_line
  http_method, path, params = parse_request(request_line)
  
  client.puts "HTTP/1.0 200 OK"
  client.puts "Content-Type: text/html\r\n\r\n"
  client.puts <<-INFO
  <html>
  <body>
  <pre>
  method: #{http_method}
  path: #{path}
  params: #{params}
  </pre>
  INFO

  if params && params.key?('rolls') && params.key?('sides')
    client.puts "<h1>Rolls!</h1>"
    rolls = params['rolls'].to_i
    sides = params['sides'].to_i
    rolls.times do
      roll = rand(sides) + 1
      client.puts "<p>#{roll}</p>"
    end
  end
  client.puts "</body>"
  client.puts "</html>"
  client.close
end