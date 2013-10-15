# encoding: utf-8

require 'file-monitor'
require 'socket'
require 'yaml'

module LogfileTransfer
  Stop_cmd_file_name = '.sync_cmd_stop'
  Prompt_cmdline = 'ruby your.rb start [config.yaml]|stop|status'
  Prompt_running = 'daemon is running.'
  Prompt_exiting = 'daemon is exiting.'
  Prompt_starting = 'daemon is starting.'
  Prompt_no_running = 'daemon no running.'

  @hostname = 'localhost'
  @port = 2001
  @files = {}
  @threads = []
  @daemon_log_file_name = 'daemon.log'

  class Handler
    def init
      raise NotImplementedError.new("#{self.class.name}#init is abstract method.")
    end
    def handle
      raise NotImplementedError.new("#{self.class.name}#handle is abstract method.")
    end
  end

  class FileMonitorObj
    attr_accessor :absolute_path, :dir_disallow, :file_disallow, :file_allow, :patterns
    def initialize
      @absolute_path = ''
      @dir_disallow = []
      @file_disallow = []
      @file_allow = []
      @patterns = []
    end
  end

  def self.log msg
    @daemon_log_file.puts msg
  end

  def self.daemonize_app working_directory
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

  def self.conn cmd
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

  def self.close_files curr_time = 0
    if curr_time == 0
      # puts 'close all of files'
      @files.each do |log_file_name, log_files|
        log_files[0].close
        log_files[1].close
      end
      # puts 'empty file map'
      @files = {}
      @daemon_log_file.close
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

  def self.transfer log_file_name, obj
    for pattern, handlers in obj.patterns
      if log_file_name =~ /#{pattern}/
        index = log_file_name.rindex('/')
        index += 1
        log_path = log_file_name[0, index]
        log_fn = log_file_name[index..log_file_name.length]

        loc_path = "#{log_path}.loc"
        loc_file_name = "#{loc_path}/#{log_fn}"

        log_file, loc_file, open_time, line_count = @files[log_file_name]

        unless log_file
          Dir.mkdir loc_path unless File.exist? loc_path

          if File.exist? loc_file_name
            loc_file = File.new(loc_file_name, 'r+')
          else
            loc_file = File.new(loc_file_name, 'w+')
          end
          loc_file.sync = true
          line_count = 0
          log_file = File.new(log_file_name, 'r')
          open_time = Time.now.to_i
          close_files open_time
        end

        while line = log_file.gets
          line_count += 1
          loc = loc_file.gets
          if loc
            next
          end

          fail = false
          fail_handlers = []

          handlers.each do |handler|
            begin
              handler.handle log_path, log_fn, line.chop, line_count, pattern
            rescue => err
              log "#{log_file_name}, #{line_count}, #{err}"
              fail_handlers << handler.class
              fail = true
            end
          end

          if fail
            loc_file.puts "#{line_count}, #{fail_handlers}"
          else
            loc_file.puts "#{line_count}"
          end

        end
        @files[log_file_name] = [log_file, loc_file, open_time, line_count]
        break
      end
    end
  end

  def self.daemon
    YAML.load_file(@config_file_name).each do |obj|
      log "absolute path: #{obj.absolute_path}"
      log "dir disallow: #{obj.dir_disallow}"
      log "file disallow: #{obj.file_disallow}"
      log "file allow: #{obj.file_allow}"
      obj.patterns.each do |pattern, handlers|
        log "pattern: #{pattern}"
        handlers.each do |handler|
          handler.init
          log "- -#{handler.class} initialized."
        end
      end

      @threads << Thread.new do
        begin
          m = FileMonitor.new(obj.absolute_path)

          m.filter_dirs do
            obj.dir_disallow.each do |dir|
              disallow /#{dir}/
            end
            disallow /loc$/
          end

          m.filter_files do
            obj.file_disallow.each do |file|
              disallow /#{file}/
            end
            obj.file_allow.each do |file|
              allow /#{file}/
            end
            allow /#{Stop_cmd_file_name}$/
          end

          m.run do |events|
            break if @exit_flag
            events.each do |event|
              flags = event.flags
              if flags.include?(:modify) or flags.include?(:moved_to) or flags.include?(:create)
                transfer event.absolute_name, obj
              end
            end
          end

          log "#{obj.absolute_path} file monitor thread exit."
        rescue =>err
          # puts err
          log err
        end
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
          @exit_flag = true;

          YAML.load_file(@config_file_name).each do |obj|
            system "touch #{obj.absolute_path}/#{Stop_cmd_file_name}"
          end

          sleep 1

          YAML.load_file(@config_file_name).each do |obj|
            system "unlink #{obj.absolute_path}/#{Stop_cmd_file_name}"
          end

          # puts 'client.close'
          client.close

          break;
        when 'status'
          close_files Time.now.to_i
          client.puts(Prompt_running)
          client.puts(@config_file_title)
          @files.each do |log_file_name, log_files|
            client.puts "log file: #{log_file_name}, loc file: #{log_files[1].path}, open time: #{Time.at(log_files[2])}, lines: #{log_files[3]}"
          end
        end

        # puts 'client.close'
        client.close
      end

      close_files
      # @files.each do |k, v|
      #   puts "#{k}: #{v}"
      # end
      unless server == nil
        # puts 'server.close'
        server.close
      end
    end

    @threads.each { |t| t.join }
  end

  def self.run argv, port, working_directory
    @port = port

    if argv.length < 1
      puts Prompt_cmdline
      exit
    end

    cmd = argv[0]
    # puts "cmd: #{cmd}"

    @exit_flag = false;

    case cmd
    when 'start'
      if argv.length < 2
        @config_file_name = "#{working_directory}/config.yaml"
      elsif argv[1][0] == '/'
        @config_file_name = argv[1]
      else
        @config_file_name = "#{working_directory}/#{argv[1]}"
      end

      @config_file_title = "config file: #{@config_file_name}"

      unless File.exist? @config_file_name
        puts "#{@config_file_title} no exist!"
        exit
      end

      exit if conn 'status'

      puts Prompt_starting

      daemonize_app working_directory
      @daemon_log_file_name = "#{working_directory}/#{@daemon_log_file_name}"
      @daemon_log_file = File.new @daemon_log_file_name, 'a'
      @daemon_log_file.sync = true
      log "-------------#{Time.now}-----------------"
      daemon
    when /stop|status/
      puts Prompt_no_running unless conn cmd
    else
      puts Prompt_cmdline
    end
  end
end
