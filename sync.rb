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

def daemonize_app working_directory
  if RUBY_VERSION < "1.9"
    exit if fork
    Process.setsid
    exit if fork
    Dir.chdir working_directory
    STDIN.reopen "/dev/null"
    STDOUT.reopen "/dev/null", "a"
    STDERR.reopen "/dev/null", "a"
  else
    Process.daemon
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
  # puts "#{e}"
  false
ensure  
  s.close unless s==nil
end

@files = {}

def close_files curr_time = 0
  # puts "close_files: #{curr_time}"
  if curr_time == 0
    puts 'close all'
    @files.each do |k, v|
      v[0].close
      v[1].close
    end
    puts 'empty map'
    @files = {}
  else
    @files.each do |k, v|
      if (curr_time - v[2]) > 86400000
        puts "close #{k}"
        v[0].close
        v[1].close
        @files[k] = []
      end
    end
  end
end

stop_cmd_file_name = '.sync_cmd_stop'
prompt_cmdline = 'ruby sync.rb start [config_file]|stop|status'
prompt_running = 'sync is running!'
prompt_exiting = 'sync is exiting!'
prompt_starting = 'sync is starting!'
prompt_no_running = 'sync no running!'

class Transfer
end

class Handler
end

if ARGV.length < 1
  puts prompt_cmdline
  exit
end

working_directory = File.expand_path(File.dirname(__FILE__))
# puts working_directory

cmd = ARGV[0]
# puts "cmd: #{cmd}"

$exit_flag = false;

case cmd
when 'start'
  if ARGV.length < 2
    config_file = "#{working_directory}/sync.yaml"
  elsif ARGV[1][0] == '/'
    config_file = ARGV[1]
  else
    config_file = "#{working_directory}/#{ARGV[1]}"
  end

  config_file_title = "config file: #{config_file}"

  unless File.exist? config_file
    puts "#{config_file_title} is not exist!"
    exit
  end

  exit if conn 'status'

  puts prompt_starting
  
  daemonize_app working_directory

  threads = []

  @scribe_client = Scribe.new('127.0.0.1:1463')

  YAML.load_file(config_file).each do |obj|
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
          flags = event.flags
          if flags.include?(:modify) or flags.include?(:moved_to) or flags.include?(:create)
            fn = event.absolute_name
            # for pattern, handler in obj.patterns
            #   if fn =~ /#{pattern}/
            index = fn.rindex('/')
            dot_index = fn.index('.')

            tag = fn[index + 1..dot_index - 1]
            # puts tag

            loc_path = "#{fn[0, index]}/.loc"
            loc_file_name = "#{loc_path}#{fn[index, fn.length]}"

            log_file, loc_file = @files[fn]

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
              @files[fn] = [log_file, loc_file, Time.now.to_i]

              close_files Time.now.to_i
            end

            while line = log_file.gets
              loc = loc_file.gets
              # puts "loc: #{loc}"
              unless loc
                # puts 'sent'
                begin
                  @scribe_client.log(line.chop, tag)
                  loc_file.puts '0'
                rescue => err
                  puts err
                  loc_file.puts "1,#{line.chop}"
                end
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
    server = TCPServer.open(@hostname, @port)

    loop do
      client = server.accept

      cmd = client.gets

      case cmd.chop
      when 'stop'
        client.puts(prompt_exiting)
        $exit_flag = true;

        YAML.load_file(config_file).each do |obj|
          system 'touch ' + obj.absolute_path + '/' + stop_cmd_file_name
        end
        sleep 1
        YAML.load_file(config_file).each do |obj|
          system 'unlink ' + obj.absolute_path + '/' + stop_cmd_file_name
        end

        puts 'client.close'
        client.close

        break;
      when 'status'
        close_files Time.now.to_i
        client.puts(prompt_running)
        client.puts(config_file_title)
      end

      puts 'client.close'
      client.close
    end

    close_files
    @files.each do |k, v|
      puts "#{k}: #{v}"
    end
    unless server==nil
      puts 'server.close'
      server.close
    end
    # exit
  end

  threads.each { |t| t.join }
when /stop|status/
  puts prompt_no_running unless conn cmd
else
  puts prompt_cmdline
end
