require "socket"

def parse_request(request_line)
  # i.e. GET /?rolls=2&sides=6 HTTP/1.1
  http_method, path_and_query, http = request_line.split
  path, query = path_and_query.split('?')
  params = {}
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
  number = params.fetch('number', nil).to_i

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
      <h1>Counter</h1>
      <p>The current number is #{number}.</p>
      <a href='?number=#{number + 1}'>Add one</a>
      <a href='?number=#{number - 1}'>Subtract one</a>
    </body>
  </html>
  INFO
  client.close
end