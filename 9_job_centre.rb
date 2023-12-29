#!/usr/bin/env ruby --yjit
require 'oj'
require_relative 'lib/config'
require_relative 'lib/job_server'

Oj.mimic_JSON()

# {"request":"put","queue":"queue1","job":{"name":"brian"},"pri":123}
# {"request":"get","queues":["queue1"],"wait":true}

def handle conn, jobs
  conn.log "*connect*"
  loop do
    msg = conn.gets
    break unless msg
    conn.log("< #{msg}")
    req = JSON.parse(msg) rescue nil
    raise 'bad request' unless req
    case req['request']
    when "put"
      pri = Integer(req['pri'])
      payload = req['job']
      raise 'invalid payload' unless payload.is_a?(Hash)
      job = jobs.insert(req['queue'], pri:, payload:)
      conn.respond({status: 'ok', id: job.id})

    when "get"
      queues = req['queues']
      raise 'invalid queues' unless queues.is_a?(Array) && queues.size > 0 && queues.all?{|q| q.is_a?(String)}
      job = jobs.get_and_lock(queues, conn, wait: req['wait'] == true)
      if job
        conn.respond({status:"ok", id: job.id, job: job.payload, pri: job.pri, queue: job.queue})
      else
        conn.respond({status:"no-job"})
      end

    when "delete"
      id = Integer(req['id'])
      job = jobs.delete(id)
      conn.respond({status:job ? "ok" : "no-job"})

    when "abort"
      id = Integer(req['id'])
      job = jobs.abort(id, conn)
      conn.respond({status:job ? "ok" : "no-job"})
    else
      raise "unknown request type #{req['request'].inspect}"
    end
  rescue Errno::EPIPE, EOFError
    break
  rescue StandardError => e
    conn.respond({status: 'error', error: e.message})
  end
ensure
  jobs.disconnect conn
  conn.log("*closed*")
  conn.close
end

Connection = Struct.new(:sock) do
  def fid = sock.fileno
  def log(str) = puts("[#{fid}] #{str}")
  def gets(...) = sock.gets(...)
  def close(...) = sock.close(...)
  def respond(obj)
    obj = obj.to_json
    log("> #{obj}")
    sock.puts(obj)
  rescue Errno::EPIPE, EOFError
    # bye
  end
end

if $0 == __FILE__
  jobs = JobServer.new
  server { handle Connection[_1], jobs }
end
