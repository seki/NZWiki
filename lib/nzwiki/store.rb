require 'drip'

=begin
  prefix = project name
  page = prefix + '@' + page name
  auth = prefix + '?' + count
  control = prefix + '%' + ...
=end

module NZWiki
  class Store
    def initialize(drip, project)
      @drip = drip
      @project = project
      @auth_counter = "#{@prefix}?"
    end

    def []=(k, v)
      @drip.write(v, page_key(k))
    end

    def [](k)
      mtime, value, = @drip.head(1, page_key(k)).first
      return nil unless mtime
      mtime = @drip.key_to_time(mtime)
      [value, mtime]
    end

    def ctime(k)
      ctime, _, = @drip.read_tag(0, page_key(k), 1, 0).first
      return nil unless ctime
      @drip.key_to_time(ctime)
    end

    def auth_create
      while true
        k, v = @drip.head(1, @auth_counter).first || [0, 0]
        v += 1
        return v if @drip.write_if_latest([[@auth_counter, k]], v, @auth_counter)
      end
    end

    def auth_any
      _, size = @drip.head(1, @auth_counter).first
      return nil unless size
      auth_get(rand(size) + 1)
    end

    def auth_set(key, value)
      @drip.write(value, @auth_counter + key.to_s)
    end

    def auth_get(key)
      _, value, = @drip.head(1, @auth_counter + key.to_s).first
      value
    end

    private
    def auth_counter
      @prefix + '?'
    end

    def page_key(name)
      "#{@project}@#{name}"
    end
  end
end
