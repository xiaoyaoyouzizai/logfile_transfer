# require 'scribe'
load 'lib/logfile-transfer.rb'
class test < LogfileTransfer::Handler

  # dot_index = fn.index('.')
  # tag = fn[index + 1..dot_index - 1]
  # puts tag
  # scribe_client = Scribe.new('127.0.0.1:1463')
  # puts 'sent'
  # scribe_client.log(line.chop, tag)
  def handleMessage  log_path, log_fn, line, line_count
  	puts line
  end

end

handlers = {ToDataCenter : test.new}

LogfileTransfer.run handlers