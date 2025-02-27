# encoding: UTF-8
# frozen_string_literal: true

require "cgi"

class DummyServer < WEBrick::HTTPServer
  class Servlet < WEBrick::HTTPServlet::AbstractServlet # rubocop:disable Metrics/ClassLength
    def self.sockets
      @sockets ||= []
    end

    def not_found(req, res)
      res.status = 404
      res.body   = "#{req.unparsed_uri} not found"
    end

    def self.handlers
      @handlers ||= {}
    end

    %w[get post head].each do |method|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{method}(path, &block)
          handlers["#{method}:\#{path}"] = block
        end

        def do_#{method.upcase}(req, res)
          handler = self.class.handlers["#{method}:\#{req.path}"]
          return instance_exec(req, res, &handler) if handler
          not_found(req, res)
        end
      RUBY
    end

    get "/" do |req, res|
      res.status = 200

      case req["Accept"]
      when "application/json"
        res["Content-Type"] = "application/json"
        res.body = '{"json": true}'
      else
        res["Content-Type"] = "text/html"
        res.body = "<!doctype html>"
      end
    end

    get "/sleep" do |_, res|
      sleep 2

      res.status = 200
      res.body   = "hello"
    end

    post "/sleep" do |_, res|
      sleep 2

      res.status = 200
      res.body   = "hello"
    end

    ["", "/1", "/2"].each do |path|
      get "/socket#{path}" do |req, res|
        self.class.sockets << req.instance_variable_get(:@socket)
        res.status  = 200
        res.body    = req.instance_variable_get(:@socket).object_id.to_s
      end
    end

    get "/params" do |req, res|
      next not_found(req, res) unless "foo=bar" == req.query_string

      res.status = 200
      res.body   = "Params!"
    end

    get "/multiple-params" do |req, res|
      params = CGI.parse req.query_string

      next not_found(req, res) unless {"foo" => ["bar"], "baz" => ["quux"]} == params

      res.status = 200
      res.body   = "More Params!"
    end

    get "/proxy" do |_req, res|
      res.status = 200
      res.body   = "Proxy!"
    end

    get "/not-found" do |_req, res|
      res.status = 404
      res.body   = "not found"
    end

    get "/redirect-301" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{@server.config[:BindAddress]}:#{@server.config[:Port]}/"
    end

    get "/redirect-302" do |_req, res|
      res.status      = 302
      res["Location"] = "http://#{@server.config[:BindAddress]}:#{@server.config[:Port]}/"
    end

    post "/form" do |req, res|
      if "testing-form" == req.query["example"]
        res.status = 200
        res.body   = "passed :)"
      else
        res.status = 400
        res.body   = "invalid! >:E"
      end
    end

    post "/body" do |req, res|
      if "testing-body" == req.body
        res.status = 200
        res.body   = "passed :)"
      else
        res.status = 400
        res.body   = "invalid! >:E"
      end
    end

    head "/" do |_req, res|
      res.status          = 200
      res["Content-Type"] = "text/html"
    end

    get "/bytes" do |_req, res|
      bytes = [80, 75, 3, 4, 20, 0, 0, 0, 8, 0, 123, 104, 169, 70, 99, 243, 243]
      res["Content-Type"] = "application/octet-stream"
      res.body = bytes.pack("c*")
    end

    get "/iso-8859-1" do |_req, res|
      res["Content-Type"] = "text/plain; charset=ISO-8859-1"
      res.body = "testæ".encode(Encoding::ISO8859_1)
    end

    get "/cookies" do |req, res|
      res["Set-Cookie"] = "foo=bar"
      res.body = req.cookies.map { |c| [c.name, c.value].join ": " }.join("\n")
    end

    post "/echo-body" do |req, res|
      res.status = 200
      res.body   = req.body
    end

    get "/hello world" do |_req, res|
      res.status = 200
      res.body   = "hello world"
    end

    post "/encoded-body" do |req, res|
      res.status = 200

      res.body = case req["Accept-Encoding"]
                 when "gzip"
                   res["Content-Encoding"] = "gzip"
                   StringIO.open do |out|
                     Zlib::GzipWriter.wrap(out) do |gz|
                       gz.write "#{req.body}-gzipped"
                       gz.finish
                       out.tap(&:rewind).read
                     end
                   end
                 when "deflate"
                   res["Content-Encoding"] = "deflate"
                   Zlib::Deflate.deflate("#{req.body}-deflated")
                 else
                   "#{req.body}-raw"
                 end
    end

    post "/no-content-204" do |req, res|
      res.status = 204
      res.body   = ""

      case req["Accept-Encoding"]
      when "gzip"
        res["Content-Encoding"] = "gzip"
      when "deflate"
        res["Content-Encoding"] = "deflate"
      end
    end
  end
end
