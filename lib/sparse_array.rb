class SparseArray
  attr_reader :keys, :values
  def initialize
    @keys = []
    @values = []
  end

  def [](*args)
    case args
    in [Integer => idx]
      pos = @keys.bsearch_index{|i,| idx<=>i}
      pos && @values[pos]

    in [Range => range]
      return @values if @values.empty?
      start = range.begin || 0
      finish = range.end || @keys[-1] || 0
      p1 = @keys.bsearch_index{|i,| i>=start} || @keys.size
      p2 = @keys.bsearch_index{|i,| i>=finish} || @keys.size-1
      lastkey = @keys[p2]
      exclude_end = lastkey > finish || (range.exclude_end? && lastkey == finish)
      @values[Range.new(p1,p2,exclude_end)]

    in Integer => start, Integer => length
      p1 = @keys.bsearch_index{|i,| i>=start} || @keys.size
      p2 = @keys.bsearch_index{|i,| i>=(start+length)} || @keys.size
      @values[p1...p2]

    in [key]
      self[Integer(key)]
    else
      raise ArgumentError, "Cannot index SparseArray by #{args.inspect}"
    end
  end

  def []=(idx,val)
    pos = @keys.bsearch_index{|i,| i>=idx} || @keys.size
    @keys.insert(pos,idx)
    @values.insert(pos,val)
  end
end
