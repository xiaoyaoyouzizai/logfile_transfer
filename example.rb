# encoding: utf-8

lib_dir = File.join File.dirname(__FILE__), 'lib'
$:.unshift lib_dir unless $:.include? lib_dir

require 'logfile_transfer.rb'

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

LogfileTransfer.run ARGV, 2001, File.expand_path(File.dirname(__FILE__))