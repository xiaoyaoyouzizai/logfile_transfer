# encoding: utf-8

lib_dir = File.join File.dirname(__FILE__), 'lib'
$:.unshift lib_dir unless $:.include? lib_dir

require 'scribe'
require 'logfile_transfer.rb'

class Test < LogfileTransfer::Handler

  def initialize
    @scribe_client = Scribe.new('127.0.0.1:1463')
  end

  def handle log_path, log_fn, line, line_count, pattern
    puts "#{log_path}, #{log_fn}, #{line_count}"
  end

end

class Test1 < LogfileTransfer::Handler
  def initialize
    @scribe_client = Scribe.new('127.0.0.1:1463')
  end

  def handle log_path, log_fn, line, line_count, pattern
    if (line_count % 2) == 0
      puts '+++++++++++++++++++'
    else
      puts '-------------------'
    end
    puts 'sent'
    @scribe_client.log(line, tag)
  end

end

LogfileTransfer.run ARGV, 2001, File.expand_path(File.dirname(__FILE__))
