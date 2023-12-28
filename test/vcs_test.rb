require 'minitest/autorun'
require_relative '../10_vcs'

class VCSTest < Minitest::Test
  def setup
    @fs = Filesystem.new
    @h = Handler.new @fs
    @client, @server = Socket.pair(:UNIX, :STREAM, 0)
    @client.timeout = @server.timeout = 1
  end

  def teardown
    @client.close
    @server.close
  end

  def process = @h.process @server

  def test_help_cmd
    @client.puts "HELP"
    process
    assert_equal "OK usage: HELP|GET|PUT|LIST\n", @client.gets
  end

  def test_list_empty_dir
    @client.puts "LIST /a"
    process
    assert_equal "OK 0\n", @client.gets
  end

  def test_list_files
    @fs.write_version '/a/one', '1'
    @fs.write_version '/a/two', '2'
    @client.puts "LIST /a"
    process
    assert_equal "OK 2\none r1\ntwo r1\n", @client.readpartial(50)
  end

  def test_list_dir
    @fs.write_version '/a/one', '1'
    @client.puts "LIST /"
    process
    assert_equal "OK 1\na/ DIR\n", @client.readpartial(50)
  end

  def test_write_file
    @client.write "PUT /a 2\n1\n"
    process
    assert_equal "OK r1\n", @client.gets
  end

  def test_read_nonexistent
    @client.puts "GET /foo"
    process
    assert_equal "ERR no such file\n", @client.gets
  end

  def test_read
    @fs.write_version '/foo', "1\n"
    @client.puts "GET /foo"
    process
    assert_equal "OK 2\n1\n", @client.readpartial(50)
  end

  def test_read_rev
    @fs.write_version '/foo', "1\n"
    @client.puts "GET /foo r1"
    process
    assert_equal "OK 2\n1\n", @client.readpartial(50)
  end

  def test_invalid_cmd
    @client.puts "BOOYA"
    process
    assert_equal "ERR illegal method: BOOYA\n", @client.gets
  end
end
