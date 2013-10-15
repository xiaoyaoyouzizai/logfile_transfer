# encoding: utf-8

lib_dir = File.join File.dirname(__FILE__), 'lib'
$:.unshift lib_dir unless $:.include? lib_dir

require 'scribe'
require 'logfile_transfer.rb'

class Test < LogfileTransfer::Handler
  def init
  end
  def handle log_path, log_fn, line, line_count, pattern
    if (line_count % 2) == 0
      puts '+++++++++++++++++++'
    else
      puts '-------------------'
    end
    puts "#{log_path}, #{log_fn}, #{line_count}, #{pattern}"
  end
end

class Test1 < LogfileTransfer::Handler
  def init
    @scribe_client = Scribe.new('127.0.0.1:1463')
  end
  def handle log_path, log_fn, line, line_count, pattern
    @scribe_client.log(line, pattern)
  end
end

LogfileTransfer.run ARGV, 2001, File.expand_path(File.dirname(__FILE__))