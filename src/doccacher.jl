using JSON

function serve(port)
  server = listen(ip"127.0.0.1", port)
  sock = accept(server)
  @async while isopen(sock)
      msg = JSON.parse(sock)
      @schedule handlemsg(msg...)
  end
end

function
