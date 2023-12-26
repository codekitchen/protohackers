module ReqId
  @id = 0
  @lock = Mutex.new
  def self.next = @lock.synchronize { @id+=1 }
end
