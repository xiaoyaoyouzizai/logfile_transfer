# encoding: utf-8
require 'scribe'
require 'file-monitor'
require 'socket'
require 'yaml'

@hostname = 'localhost'
@port = 2000

class FileMonitorObj
  attr_accessor :absolute_path, :dir_disallow, :file_disallow, :file_allow, :patterns
  def initialize absolute_path, dir_disallow, file_disallow, file_allow
    @absolute_path = absolute_path
    @dir_disallow = dir_disallow
    @file_disallow = file_disallow
    @file_allow = file_allow
    @patterns = []
  end
end

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
  exit! if conn 'status'

  puts prompt_starting
  threads = []
  files = {}
  client = Scribe.new('127.0.0.1:1463')
  YAML.load_file('sync.yaml').each do |obj|
    puts obj.absolute_path
    puts obj.dir_disallow
    puts obj.file_disallow
    puts obj.file_allow
    obj.patterns.each do |pattern, handler|
      puts "#{pattern}: #{handler}"
    end

    threads << Thread.new do
      m = FileMonitor.new(obj.absolute_path)

      m.filter_dirs do
        disallow /#{obj.dir_disallow}/
      end

      m.filter_files do
        disallow /#{obj.file_disallow}/
        allow /#{obj.file_allow}|#{stop_cmd_file_name}$/
      end

      m.run do |events|
        break if $exit_flag
        events.each do |event|
          if event.flags[0] == :modify
            fn = event.absolute_name
            # for pattern, handler in obj.patterns
            #   if fn =~ /#{pattern}/
            index = fn.rindex('/')
            dot_index = fn.index('.')

            tag = fn[index + 1..dot_index - 1]
            # puts tag

            loc_path = "#{fn[0, index]}/.loc"
            loc_file_name = "#{loc_path}#{fn[index, fn.length]}"

            log_file, loc_file = files[fn]

            if loc_file
              # puts 'from map'
            else
              # puts 'init'
              Dir.mkdir loc_path unless File.exist? loc_path

              if File.exist? loc_file_name
                loc_file = File.new(loc_file_name, 'r+')
              else
                loc_file = File.new(loc_file_name, 'w+')
              end
              log_file = File.new(fn)
              files[fn] = [log_file, loc_file]
            end

            while line = log_file.gets
              loc = loc_file.gets
              # puts "loc: #{loc}"
              unless loc
                # puts 'sent'
                client.log(line.chop, tag)
                loc_file.puts '0'
              end
            end

            #     break
            #   end
            # end
          end
        end
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
when /stop|status/
  puts prompt_no_running unless conn cmd
else
  puts prompt_cmdline
end
