require "minitest/autorun"
require_relative 'filesystem'

class FilesystemTest < Minitest::Test
  def setup
    @fs = Filesystem.new
    @contents = "Hello, World!\n"
  end

  def test_empty_fs
    assert_equal 0, @fs.filecount
  end

  def test_write_read_file
    rev = @fs.write_version '/foo', @contents
    assert_equal 1, rev
    assert_equal @contents, @fs.read('/foo')
    assert_equal @contents, @fs.read('/foo', 1)
  end

  def test_get_file_info
    @fs.write_version '/foo', @contents
    info = @fs.get_file '/foo'
    assert_equal 1, info.revisions.count
    assert_equal 'foo', info.name
  end

  def test_list_dir
    @fs.write_version '/a/one', @contents
    @fs.write_version '/a/two', @contents
    @fs.write_version '/a/b/other', @contents
    files = @fs.list('/a')
    assert_equal 2, files.length
    assert_equal 'one', files[0].name
    assert_equal 'two', files[1].name
    assert_equal false, files[0].dir?
  end

  def test_list_filename
    @fs.write_version '/foo', @contents
    files = @fs.list('/foo')
    assert_equal [], files
  end

  def test_list_dir
    @fs.write_version '/a/one', @contents
    files = @fs.list('/')
    assert_equal 1, files.size
    assert_equal 'a', files[0].name
    assert_equal true, files[0].dir?
  end

  def test_filecount
    @fs.write_version '/a/one', @contents
    @fs.write_version '/a/two', @contents
    @fs.write_version '/a/b/other', @contents
    assert_equal 3, @fs.filecount
  end

  def test_read_nonexistent
    assert_raises(Filesystem::Error) {@fs.read('/foo')}
  end

  def test_reject_nonascii
    contents = "Hello \x01"
    assert_raises(Filesystem::Error) {@fs.write_version('/foo', contents)}
  end

  def test_list_empty
    assert [], @fs.list('/a')
  end

  def test_write_invalid_path
    assert_raises(Filesystem::Error) { @fs.write_version 'foo', @contents }
    assert_raises(Filesystem::Error) { @fs.write_version '//a', @contents }
    assert_raises(Filesystem::Error) { @fs.write_version "/a'a", @contents }
    assert_raises(Filesystem::Error) { @fs.write_version '/a{a', @contents }
  end

  def test_write_new_version
    c2 = "second"
    @fs.write_version '/foo', @contents
    @fs.write_version '/foo', c2
    assert_equal c2, @fs.read('/foo')
    assert_equal @contents, @fs.read('/foo', 1)
  end

  def test_write_duplicate_revision
    assert_equal 1, @fs.write_version('/foo', @contents)
    assert_equal 1, @fs.write_version('/foo', @contents)
    assert_equal 1, @fs.get_file('/foo').revisions.size
    assert_equal 2, @fs.write_version('/foo', "second")
  end

  def test_read_nonexistent_revision
    @fs.write_version '/foo', @contents
    assert_raises(Filesystem::Error) {@fs.read('/foo', 2)}
    assert_raises(Filesystem::Error) {@fs.read('/foo', 0)}
    assert_raises(Filesystem::Error) {@fs.read('/foo', -1)}
  end
end
