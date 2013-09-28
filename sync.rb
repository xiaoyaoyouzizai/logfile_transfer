require 'scribe'
require 'file-monitor'
require 'socket'
require 'yaml'

class FileMonitorObj
  attr_accessor :absolute_path, :dir_disallow, :file_disallow, :file_allow
  def initialize absolute_path, dir_disallow, file_disallow, file_allow
    @absolute_path = absolute_path
    @dir_disallow = dir_disallow
    @file_disallow = file_disallow
    @file_allow = file_allow
  end
end

a = []
a1 = FileMonitorObj.new '/data/log', '/\.git|\.svn/', '/.*/', '/\.rb$/'
a << a1
File.open("sync.yaml", "w") do |io|
  YAML.dump(a, io)
end

prompt = 'ruby sync.rb start|stop|status'
if ARGV.length < 1
  puts prompt
  exit!
end

cmd = ARGV[0]
dir = ARGV[1]

case cmd
when 'start'
  YAML.load_file("sync.yaml").each do |obj|
    puts obj.absolute_path
  end
when 'stop'
when 'status'
else
  puts prompt
  exit!
end

puts "cmd: #{cmd}"
puts "dir: #{dir}"
$exit_flag= false;
hostname = 'localhost'
port = 2000

begin
  s = TCPSocket.open(hostname, port)

# while line = s.gets   # Read lines from the socket
#   puts line.chop      # And print with platform line terminator
# end
s.puts 'exit'
s.close               # Close the socket when done

exit!
rescue Exception=>e
  puts "eee:#{e}"
end



threads = []

threads << Thread.new {  
  server = TCPServer.open(port)
  loop {
    client = server.accept
    # client.puts(dir) # Send the time to the client
    cmd = client.gets
    puts cmd
    if cmd.chop == "exit"

      $exit_flag= true;
      puts "exit_flag:#{$exit_flag}"
      break;
    end
    client.close                # Disconnect from the client
  }
}


threads << Thread.new {
  puts 'hahah'
  m = FileMonitor.new(dir)
  m.filter_dirs {
    disallow /\.git|\.svn/
  }

# record .rb files only
m.filter_files {
  disallow  /.*/
  allow /\.rb$/
}

m.run do|events|
  break if $exit_flag
  puts events.size()
  puts "do something"
end
}
threads.each { |t| t.join }