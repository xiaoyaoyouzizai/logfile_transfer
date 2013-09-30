require 'scribe'
require 'file-monitor'
require 'socket'
require 'yaml'

@hostname = 'localhost'
@port = 2000

class FileMonitorObj
  attr_accessor :absolute_path, :dir_disallow, :file_disallow, :file_allow
  def initialize absolute_path, dir_disallow, file_disallow, file_allow
    @absolute_path = absolute_path
    @dir_disallow = dir_disallow
    @file_disallow = file_disallow
    @file_allow = file_allow
  end
end

# a = []
# a1 = FileMonitorObj.new '/data/webroot/log', '/loc$/', '/.*/', '/\.log\.|\.sync_cmd_stop$/'
# a << a1
# File.open("sync.yaml", "w") do |io|
#   YAML.dump(a, io)
# end

def conn cmd
  s = TCPSocket.open(@hostname, @port)
  s.puts cmd

  while line = s.gets
    puts line.chop
  end

  true
rescue =>e
  puts "#{e}"
  false
ensure  
  s.close unless s==nil
end

stop_cmd_file_name = '.sync_cmd_stop'
prompt_cmdline = 'ruby sync.rb start|stop|status'
prompt_running = 'sync is running!'
prompt_exiting = 'sync is exiting!'
prompt_starting = 'sync is starting!'
prompt_no_running = 'sync is not running!'

if ARGV.length < 1
  puts prompt_cmdline
  exit!
end

cmd = ARGV[0]
puts "cmd: #{cmd}"

$exit_flag= false;

case cmd
when 'start'
  unless conn 'status'
    puts prompt_starting
    threads = []

    YAML.load_file('sync.yaml').each do |obj|
      puts obj.absolute_path
      puts obj.dir_disallow
      puts obj.file_disallow
      puts obj.file_allow

      threads << Thread.new do
        m = FileMonitor.new(obj.absolute_path)
        
        m.filter_dirs do
          disallow /loc$/
        end

        m.filter_files do
          disallow /.*/
          allow /\.log\.|\.sync_cmd_stop$/
        end

        m.run do |events|
          break if $exit_flag
          puts events.size()
          puts "do something"
        end
        puts 'FileMonitor thread exit!'
      end
    end

    threads << Thread.new do
      server = TCPServer.open(@port)

      loop do
        client = server.accept

        cmd = client.gets

        case cmd.chop
        when 'stop'
          client.puts(prompt_exiting)
          $exit_flag = true;

          YAML.load_file('sync.yaml').each do |obj|
            system 'touch ' + obj.absolute_path + '/' + stop_cmd_file_name
          end
          sleep 1
          YAML.load_file('sync.yaml').each do |obj|
            system 'unlink ' + obj.absolute_path + '/' + stop_cmd_file_name
          end
          break;
        when 'status'
          client.puts(prompt_running)
        end

        puts 'client.close'
        client.close
      end

      puts 'server.close'
      server.close unless server==nil
    end

    threads.each { |t| t.join }
  end
when /stop|status/
  puts prompt_no_running unless conn cmd
else
  puts prompt_cmdline
end
