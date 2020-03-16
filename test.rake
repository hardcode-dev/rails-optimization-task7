# frozen_string_literal: true

namespace :test do
  desc "run"
  task run: :environment do
    abort "InfluxDB server is not running!" unless influx_running?

    cmd = "rake parallel:spec[3]"
    puts "Running rspec via `#{cmd}`"

    start = Time.now
    system(cmd)
    finish = Time.now
    puts "Total time is #{finish - start}"

    puts "SENDING METRIC TO INFLUXDB"
    TestMetrics.write(user: ENV["DEVELOPER"], run_time_seconds: (finish - start).to_i)
  end

  private

  def influx_running?
    influx_endpoint = ENV["INFLUX_ENDPOINT"]
    puts "Checking InfluxDB on #{influx_endpoint}"

    system("curl #{influx_endpoint}/ping")
  end
end
