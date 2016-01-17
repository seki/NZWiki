require 'drip'

=begin
  prefix = project name
  page = prefix + '@0' + page name
  auth = prefix + '?0' + count
  control = prefix + '%' + ...
=end

module NZWiki
  class Store
    def initialize(drip, project)
      @drip = drip
      @project = project
      @auth_counter = "#{@project}?"
    end

    def []=(k, v)
      @drip.write(v, page_key(k))
    end

    def [](k)
      key, value, = @drip.head(1, page_key(k)).first
      return nil unless key
      value
    end

    def ctime(k)
      ctime, _, = @drip.read_tag(0, page_key(k), 1, 0).first
      return nil unless ctime
      @drip.key_to_time(ctime)
    end

    def next_page(k)
      tag = @drip.tag_next(page_key(k))
      tag_to_key(tag)
    end

    def each_page
      return to_enum(__method__) unless block_given?

      tag = "#{@project}@1"
      while tag = @drip.tag_prev(tag)
        found = tag_to_key(tag)
        break unless found
        yield(found)
      end

      nil
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
      @project + '?'
    end

    def page_key(name)
      "#{@project}@0#{name}"
    end

    def tag_to_key(tag)
      return nil unless tag
      prefix = "#{@project}@0"
      return nil unless tag[0, prefix.size] == prefix
      tmp = tag.dup
      tmp[0, prefix.size] = ''
      tmp
    end
  end
end
