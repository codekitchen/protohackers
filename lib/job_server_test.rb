require 'minitest/autorun'
require_relative 'job_server'

class JobServerTest < Minitest::Test
  def setup
    @j = JobServer.new
  end

  def payload = { 'action' => 5 }
  def workerid = 1
  def workerid2 = 2

  def test_job_insert
    j1 = @j.insert('q1', pri: 5, payload:)
    assert_equal j1.id, 1
    @j.insert('q1', pri: 3, payload:)
    @j.insert('q2', pri: 1, payload:)

    assert_equal 3, @j.queued_count
    assert_equal 2, @j.queue_count
  end

  def test_get_empty
    @j.insert('q1', pri: 5, payload:)
    j = @j.get_and_lock('q2', workerid)

    assert_nil j
  end

  def test_get_multiple_candidates
    @j.insert('q1', pri: 7, payload:)
    @j.insert('q2', pri: 5, payload:)
    win = @j.insert('q3', pri: 8, payload:)
    j = @j.get_and_lock(%w[q1 q2 q3], workerid)

    assert_equal win, j
  end

  def test_get_wait
    Sync do
      waiter = Async do
        @j.get_and_lock(%w[q1 q2], workerid, wait: true)
      end
      job = @j.insert('q2', pri: 3, payload:)
      assert_equal job, waiter.wait
    end
  end

  def test_lock_two_jobs
    j1 = @j.insert('q1', pri: 7, payload:)
    j2 = @j.insert('q1', pri: 5, payload:)

    assert_equal j1, @j.get_and_lock('q1', workerid)
    assert_equal j2, @j.get_and_lock('q1', workerid)
    assert_equal 2, @j.working_count
  end

  def test_delete_job
    j1 = @j.insert('q1', pri: 7, payload:)
    j2 = @j.insert('q1', pri: 5, payload:)

    assert_equal j1, @j.delete(j1.id)
    assert_nil @j.delete(j1.id)
    assert_equal 1, @j.queued_count
  end

  def test_delete_locked_job
    j1 = @j.insert('q1', pri: 7, payload:)
    j2 = @j.insert('q1', pri: 5, payload:)

    assert_equal j1, @j.get_and_lock('q1', workerid)
    assert_equal j1, @j.delete(j1.id)
    assert_equal 1, @j.queued_count
    assert_equal 0, @j.working_count
  end

  def test_abort_own_job
    j1 = @j.insert('q1', pri: 7, payload:)
    @j.get_and_lock('q1', workerid)

    assert_equal j1, @j.abort(j1.id, workerid)
    assert_nil @j.abort(j1.id, workerid)
  end

  def test_abort_deleted_job
    assert_nil @j.abort(1234, workerid)
  end

  def test_abort_others_job
    j1 = @j.insert('q1', pri: 7, payload:)
    @j.get_and_lock('q1', workerid)

    assert_raises { @j.abort(j1.id, workerid2) }
  end

  def test_disconnect
    j1 = @j.insert('q1', pri: 7, payload:)
    j2 = @j.insert('q1', pri: 5, payload:)
    @j.get_and_lock('q1', workerid)
    @j.get_and_lock('q1', workerid)

    assert_equal 2, @j.working_count
    @j.disconnect(workerid)
    assert_equal 0, @j.working_count
    assert_equal 2, @j.queued_count
  end
end
