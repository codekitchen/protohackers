class Filesystem
  File = Struct.new(:name, :revisions) do
    def dir? = false
  end
  Dir = Struct.new(:name) do
    def dir? = true
  end
  class Error < StandardError; end

  def initialize
    @files = {}
  end

  def check_path(path)
    legal = path &&
      path[0] == '/' &&
      path[1..].split('/').all? { |part| part =~ %r{^[-._\w]+$} }
    raise Error, 'illegal file name' unless legal
  end

  def check_contents contents
    raise Error, 'illegal file contents' if contents.force_encoding('binary') =~ /[^\x7\x9\xa\xc\xd\x1b\x20-\x7e]/n
  end

  def write_version(path, contents)
    check_path path
    check_contents contents
    file = (@files[path] ||= File.new(path.split('/').last, []))
    file.revisions << contents unless file.revisions[-1] == contents
    file.revisions.size
  end

  def get_file(path)
    check_path path
    @files[path]
  end
  def read(path, rev=nil)
    file = get_file path
    raise Error, 'no such file' unless file
    raise Error, 'no such revision' if rev && !(0...file.revisions.size).include?(rev-1)
    file.revisions[rev ? rev-1 : -1]
  end

  def list(dir)
    check_path dir
    # this is complex because Filesystem isn't actually storing a tree, just a flat list
    prefixed = @files.select {|path,| path.size > dir.size && path.start_with?(dir) }
    files, subdir_files = prefixed.partition {|path,| !path.index('/', dir.size+1)}
    dirs = subdir_files.filter_map {|path,| path[dir.size..].split('/').first}.uniq.map{Dir.new _1}
    files = files.map(&:last)
    dirs + files
  end

  def filecount = @files.size
end
