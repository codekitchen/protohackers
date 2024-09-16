require 'async'

Console.logger.debug!
Async(finished: ::Async::Condition.new) {
  Async { loop { sleep 1 } }
  raise "whoops"
}
