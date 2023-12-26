EventLog = Struct.new(:context) do
  def event(**a)
    ev = context.merge(a)
    $mon.event ev
    puts ev.to_json
  end
  def with(**a) = EventLog.new(context.merge(a))
end
$log = EventLog.new({})
