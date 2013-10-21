# Logfile Transfer

Ruby monitoring and transform logfiles daemon.

## Installation

    gem install logfile_transfer
    # you may need to run:
    sudo gem install logfile_transfer

## Examples

### Edit example.rb

    require 'logfile_transfer'

    class Test < LogfileTransfer::Handler

      def init
        @test_log_file = File.new '/tmp/test.log', 'a'
        @test_log_file.sync = true
      end

      def handle log_path, log_fn, line, line_count, pattern
        @test_log_file.puts "#{log_path}, #{log_fn}, #{line_count}, #{pattern}"
      end

    end

    # The daemon binding on port 2000, make it different in other daemon
    LogfileTransfer.run ARGV, 2000, File.expand_path(File.dirname(__FILE__))

### Edit config.yaml

    ---
    - !ruby/object:LogfileTransfer::FileMonitorObj
      absolute_path: /data/webroot/log
      dir_disallow: []
      file_disallow:
      - .*
      file_allow:
      - \.log\.
      patterns:
      - - .*
        - - !ruby/object:Test {}

## Run

    # as root user, run:
    Ruby example.rb start
    # you may need to run:
    sudo Ruby example.rb start

## Status

    Ruby example.rb status

## Stop

    Ruby example.rb stop

## Multiple folders, different log and more Handler in a daemon process

### Edit example.rb

    require 'logfile_transfer'

    class Test < LogfileTransfer::Handler

      def init
        @test_log_file = File.new '/tmp/test.log', 'a'
        @test_log_file.sync = true
      end

      def handle log_path, log_fn, line, line_count, pattern
        @test_log_file.puts "#{log_path}, #{log_fn}, #{line_count}, #{pattern}"
      end

    end

    class Test1 < LogfileTransfer::Handler

      def init
        @test1_log_file = File.new '/tmp/test1.log', 'a'
        @test1_log_file.sync = true
      end

      def handle log_path, log_fn, line, line_count, pattern
        @test1_log_file.puts line
      end

    end

    LogfileTransfer.run ARGV, 2000, File.expand_path(File.dirname(__FILE__))

### Edit config.yaml

    ---
    - !ruby/object:LogfileTransfer::FileMonitorObj
      absolute_path: /data/webroot/log
      dir_disallow: []
      file_disallow:
      - .*
      file_allow:
      - \.log\.
      patterns:
      - - gamestart
        - - !ruby/object:Test {}
          - !ruby/object:Test1 {}
      - - gamestop
        - - !ruby/object:Test {}
          - !ruby/object:Test1 {}
    - !ruby/object:LogfileTransfer::FileMonitorObj
      absolute_path: /data/webroot/tlog
      dir_disallow: []
      file_disallow:
      - .*
      file_allow:
      - \.log\.
      patterns:
      - - gamestart
        - - !ruby/object:Test {}
          - !ruby/object:Test1 {}
