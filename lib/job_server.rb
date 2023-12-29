require 'async'
require 'pqueue'

# A priority queue isn't really the right choice here, since we have the
# requirement to delete from anywhere in the queue not just the top.
# But, this queue I'm using is actually implemented as
# a sorted array with binary search for inserts, so I made it work
# well enough by just deleting with a search from the top down.
class JobServer
  class Err < StandardError; end
  Job = Struct.new(:id, :pri, :payload, :queue, :locked_by)

  def initialize
    @jobs = {}
    @queues = Hash.new { |h,k| h[k] = PQueue.new { _1.pri <=> _2.pri } }
    @locked = Hash.new { |h,k| h[k] = Set.new } # worker => jobids
    @waiting = {} # worker => [queues, cond]
    @ids = (1..).each
  end

  def insert(queue, pri:, payload:)
    Job.new(id: next_id, pri:, payload:, queue:).tap { |job|
      @jobs[job.id] = job
      mark_ready job
    }
  end

  def get_and_lock(queues, worker, wait: false)
    queues = Array(queues)
    candidates = queues.map {|q| @queues[q]&.peek}.compact
    winner = candidates.sort_by(&:pri).last
    if winner
      lock_job(winner, worker)
    elsif wait
      cond = Async::Condition.new
      @waiting[worker] = [queues, cond]
      cond.wait
    end
  end

  def delete(id)
    job = @jobs.delete(id)
    if job
      @locked[job.locked_by].delete(job.id) if job.locked_by
      @queues[job.queue].delete(job) unless job.locked_by
    end
    job
  end

  def abort(id, worker)
    job = @jobs[id]
    return nil unless job && job.locked_by
    raise Err, "job #{id} is locked by another worker" if job.locked_by != worker
    @locked[job.locked_by].delete(job.id)
    mark_ready job
    job
  end

  def disconnect(worker)
    @locked[worker].dup.each {|jid| abort(jid, worker)}
    @locked.delete worker
    if @waiting[worker]
      @waiting[worker].last.signal nil
      @waiting.delete worker
    end
  end

  def next_id = @ids.next
  def queue_count = @queues.count
  def queued_count = @queues.sum {_2.size}
  def working_count = @locked.sum {_2.size}

  private

  def mark_ready(job)
    job.locked_by = nil
    @queues[job.queue] << job
    maybe_tickle(job)
  end

  def lock_job(job, worker)
    @queues[job.queue].delete(job)
    @locked[worker] << job.id
    job.locked_by = worker
    job
  end

  def maybe_tickle(job)
    worker, _ = @waiting.find {|w,(qs,c)| qs.include?(job.queue)}
    if worker
      _, waiter = @waiting.delete worker
      waiter.signal(lock_job job, worker)
    end
  end
end

# monkeys everywhere
class PQueue
  def delete(el)
    idx = @que.rindex el
    @que.delete_at idx if idx
  end
end
