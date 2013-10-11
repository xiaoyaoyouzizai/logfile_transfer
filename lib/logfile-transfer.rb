# encoding: utf-8

require 'file-monitor'
require 'socket'
require 'yaml'

module LogfileTransfer
  Stop_cmd_file_name = '.sync_cmd_stop'
  Prompt_cmdline = 'ruby your.rb start [config.yaml]|stop|status'
  Prompt_running = 'sync is running.'
  Prompt_exiting = 'sync is exiting.'
  Prompt_starting = 'sync is starting.'
  Prompt_no_running = 'sync no running.'

  def initialize
    @hostname = 'localhost'
    @port = 0
    @files = {}
    @threads = []
    @handlers = {}
  end

  class Handler
    def handle
      raise NotImplementedError.new("#{self.class.name}#area is abstract method.")
    end
  end

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

  def LogfileTransfer.daemonize_app working_directory
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

  def LogfileTransfer.conn cmd
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

  def LogfileTransfer.close_files curr_time = 0
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

  def LogfileTransfer.transfer log_file_name, obj
    for pattern, handler_names in obj.patterns
      if log_file_name =~ /#{pattern}/
        index = log_file_name.rindex('/')
        log_path = log_file_name[0, index]
        log_fn = log_file_name[index..log_file_name.length]

        loc_path = "#{log_path}/.loc"
        loc_file_name = "#{loc_path}#{log_fn}"

        log_file, loc_file, open_time, line_count = @files[log_file_name]

        unless log_file
          Dir.mkdir loc_path unless File.exist? loc_path

          if File.exist? loc_file_name
            loc_file = File.new(loc_file_name, 'r+')
          else
            loc_file = File.new(loc_file_name, 'w+')
          end
          log_file = File.new(log_file_name)
          @files[log_file_name] = [log_file, loc_file, Time.now.to_i, 0]

          close_files Time.now.to_i
        end

        while line = log_file.gets
          loc = loc_file.gets
          # puts "loc: #{loc}"
          unless loc
            line_count += 1
            fail = false

            handler_names.each do |handler_name|
              begin
                # puts line
                handler = @handlers[handler_name]
                handler.handle(log_path, log_fn, line, line_count) unless handler == nil
              rescue => err
                puts err
                fail = true
              end
            end

            if fail
              loc_file.puts "#{line_count},#{line.chop}"
            else
              loc_file.puts "#{line_count}"
            end
          end
        end

        break
      end
    end
  end

  def LogfileTransfer.daemon
    YAML.load_file(config_file).each do |obj|
      puts obj.absolute_path
      puts obj.dir_disallow
      puts obj.file_disallow
      puts obj.file_allow
      obj.patterns.each do |pattern, handler|
        puts "#{pattern}: #{handler}"
      end

      @threads << Thread.new do

        m = FileMonitor.new(obj.absolute_path)

        m.filter_dirs do
          disallow /#{obj.dir_disallow}/
        end

        m.filter_files do
          disallow /#{obj.file_disallow}/
          allow /#{obj.file_allow}|#{Stop_cmd_file_name}$/
        end

        m.run do |events|
          break if $exit_flag
          events.each do |event|
            flags = event.flags
            if flags.include?(:modify) or flags.include?(:moved_to) or flags.include?(:create)
              transfer event.absolute_name obj
            end
          end
        end

        puts 'FileMonitor thread exit!'
      end
    end

    @threads << Thread.new do
      server = TCPServer.open(@hostname, @port)

      loop do
        client = server.accept

        cmd = client.gets

        case cmd.chop
        when 'stop'
          client.puts(Prompt_exiting)
          $exit_flag = true;

          YAML.load_file(config_file).each do |obj|
            system "touch #{obj.absolute_path}/#{Stop_cmd_file_name}"
          end

          sleep 1

          YAML.load_file(config_file).each do |obj|
            system "unlink #{obj.absolute_path}/#{Stop_cmd_file_name}"
          end

          puts 'client.close'
          client.close

          break;
        when 'status'
          close_files Time.now.to_i
          client.puts(Prompt_running)
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
    end

    @threads.each { |t| t.join }
  end

  def LogfileTransfer.run argv, port, handlers, working_directory
    @port = port
    @handlers = handlers

    if argv.length < 1
      puts Prompt_cmdline
      exit
    end

    cmd = argv[0]
    # puts "cmd: #{cmd}"

    $exit_flag = false;

    case cmd
    when 'start'
      if argv.length < 2
        config_file = "#{working_directory}/config.yaml"
      elsif argv[1][0] == '/'
        config_file = argv[1]
      else
        config_file = "#{working_directory}/#{argv[1]}"
      end

      config_file_title = "config file: #{config_file}"

      unless File.exist? config_file
        puts "#{config_file_title} is not exist!"
        exit
      end

      exit if conn 'status'

      puts Prompt_starting

      # daemonize_app working_directory

      daemon
    when /stop|status/
      puts Prompt_no_running unless conn cmd
    else
      puts Prompt_cmdline
    end
  end
end