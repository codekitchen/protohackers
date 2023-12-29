require 'benchmark'
require_relative '../lib/job_server'

N = 50000

Benchmark.bmbm do |x|
  x.report("pqueue") do
    ids = (1..).each
    jobs = {}
    q = PQueue.new { _1.pri <=> _2.pri }
    N.times {
      job = JobServer::Job.new(ids.next, rand(1..500), {}, 1)
      jobs[job.id] = job
      q << job
    }
    N.times {
      job = q.peek
      raise 'nope' unless job == q.delete(job)
      jobs.delete job.id
    }
  end
end
