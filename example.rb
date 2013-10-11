lib_dir = File.join File.dirname(__FILE__), 'lib'
$:.unshift lib_dir unless $:.include? lib_dir

# require 'scribe'
require "logfile-transfer.rb"

class Test < LogfileTransfer::Handler

  # dot_index = fn.index('.')
  # tag = fn[index + 1..dot_index - 1]
  # puts tag
  # scribe_client = Scribe.new('127.0.0.1:1463')
  # puts 'sent'
  # scribe_client.log(line.chop, tag)

  def handle log_path, log_fn, line, line_count
  	puts line
  end

end

handlers = {ToDataCenter: Test.new}

LogfileTransfer.run ARGV, 2001, handlers, File.expand_path(File.dirname(__FILE__))