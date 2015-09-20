#!/usr/bin/env rake
require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new

task :test => :spec

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    $stderr.puts "RuboCop is disabled"
  end
end

require "yardstick/rake/measurement"
Yardstick::Rake::Measurement.new do |measurement|
  measurement.output = "measurement/report.txt"
end

require "yardstick/rake/verify"
Yardstick::Rake::Verify.new do |verify|
  verify.require_exact_threshold = false
  verify.threshold = 55
end

task :generate_status_codes do
  require "http"
  require "nokogiri"

  url = "http://www.iana.org/assignments/http-status-codes/http-status-codes.xml"
  xml = Nokogiri::XML HTTP.get url
  arr = xml.xpath("//xmlns:record").reduce [] do |a, e|
    code = e.xpath("xmlns:value").text.to_s
    desc = e.xpath("xmlns:description").text.to_s

    next a if "Unassigned" == desc || "(Unused)" == desc

    a << "#{code} => #{desc.inspect}"
  end

  File.open("./lib/http/response/status/reasons.rb", "w") do |io|
    io.puts <<-TPL.gsub(/^[ ]{6}/, "")
      # AUTO-GENERATED FILE, DO NOT CHANGE IT MANUALLY

      require "delegate"

      module HTTP
        class Response
          class Status < ::Delegator
            # Code to Reason map
            #
            # @example Usage
            #
            #   REASONS[400] # => "Bad Request"
            #   REASONS[414] # => "Request-URI Too Long"
            #
            # @return [Hash<Fixnum => String>]
            REASONS = {
              #{arr.join ",\n              "}
            }.each { |_, v| v.freeze }.freeze
          end
        end
      end
    TPL
  end
end

task :default => [:spec, :rubocop, :verify_measurements]
