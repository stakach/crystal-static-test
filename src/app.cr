require "option_parser"

exit_requested = false
run_error_test = false
run_count = -1_i64
sleep_time = 1.0

# Command line options
OptionParser.parse(ARGV.dup) do |parser|
  parser.banner = "Usage: static [arguments]"

  parser.on("-c COUNT", "--count=COUNT", "Specifies the number of times a test should be run") do |c|
    run_count = c.to_i64
  end

  parser.on("-e", "--error-test", "Specifies that the exception test should be run") do
    run_error_test = true
  end

  parser.on("-s TIME", "--sleep=TIME", "Fractional time in seconds to sleep between tests") do |t|
    sleep_time = t.to_f64
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end
end

terminate = Proc(Signal, Nil).new do |signal|
  puts " > terminating gracefully"
  exit_requested = true
  signal.ignore
end

# Detect ctr-c to shutdown gracefully
# Docker containers use the term signal
Signal::INT.trap &terminate
Signal::TERM.trap &terminate

exit_channel = Channel(Exception?).new

spawn do
  last_error = nil

  if run_error_test
    puts "running exception test:"
    loop do
      caught = false
      begin
        print "!"
        raise "example error" if run_error_test
        puts "FAILED TO RAISE"
        break
      rescue error
        last_error = error
        caught = true
      end

      if caught
        print "."
      else
        puts "NOT RESCUED"
        break
      end

      # want to ensure the compiler doesn't optimise away anything
      run_count -= 1
      if run_count == 0 || exit_requested
        run_error_test = false
        break
      end
      sleep sleep_time
    end
  end

  exit_channel.send last_error
end

exited_with = exit_channel.receive

puts ""
puts "test terminated"
puts "last error was: #{exited_with.try &.inspect_with_backtrace}"
