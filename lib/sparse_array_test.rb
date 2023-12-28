require "minitest/autorun"
require_relative 'sparse_array'

class SparseArrayTest < Minitest::Test
  def setup
    @a = SparseArray.new
    @a[17] = 8
    @a[995] = 9
    @a[21] = 4
  end

  def test_index_int
    assert_equal 8, @a[17]
    assert_nil @a[16]
  end

  def test_index_start_length
    assert_equal [8], @a[15,4]
    assert_equal [], @a[15,2]
    assert_equal [8], @a[15,3]
    assert_equal [8], @a[15,6]
    assert_equal [8,4], @a[15,7]
    assert_equal [8,4,9], @a[15,2000]
    assert_equal [8,4,9], @a[0,2000]
  end

  def test_index_range
    assert_equal [], @a[0..15]
    assert_equal [], @a[50..3]
    assert_equal [8], @a[0..17]
    assert_equal [8], @a[17..17]
    assert_equal [], @a[0...17]
    assert_equal [8], @a[0...18]
    assert_equal [8,4,9], @a[0...996]
  end

  def test_beginless_range
    assert_equal [], @a[..15]
    assert_equal [8], @a[..17]
  end

  def test_endless_range
    assert_equal [8,4,9], @a[0..]
    assert_equal [9], @a[22..]
    assert_equal [9], @a[995..]
    assert_equal [], @a[996..]
  end

  def test_empty
    @b = SparseArray.new
    assert_nil @b[0]
    assert_equal [], @b[0,55]
    assert_equal [], @b[0..15]
    assert_equal [], @b[15..0]
  end
end
