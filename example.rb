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
  	puts "#{log_path}, #{log_fn}, #{line_count}"
  end

end

class Test1 < LogfileTransfer::Handler

  # dot_index = fn.index('.')
  # tag = fn[index + 1..dot_index - 1]
  # puts tag
  # scribe_client = Scribe.new('127.0.0.1:1463')
  # puts 'sent'
  # scribe_client.log(line.chop, tag)

  def handle log_path, log_fn, line, line_count
  	if (line_count % 2) == 0
  		puts '+++++++++++++++++++'
  	else
  		puts '-------------------'
  	end
  end

end

LogfileTransfer.run ARGV, 2001, File.expand_path(File.dirname(__FILE__))