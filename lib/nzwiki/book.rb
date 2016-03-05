# -*- coding: utf-8 -*-
require 'drip'
require 'erb'

module NZWiki
  class Book
    def initialize(store)
      @monitor = Monitor.new
      @pages = {}
      @store = store
    end

    def new_page_name
      Drip.time_to_key(Time.now).to_s(36)
    end

    def timeline_page_name?(name)
      time = Drip.key_to_time(name.to_i(36))
      Time.local(2016) < time && time < Time.now
    rescue
      false
    end

    def [](name)
      @monitor.synchronize do
        @pages[name] || Page.new(@store[name])
      end
    end

    def update(name, src, author)
      @monitor.synchronize do
        page = self[name]
        @pages[name] = page
        page.update(src, author)
        @store[name] = page.to_hash
      end
    end

    def recent_names
      @store.each_page.lazy.select {|x| timeline_page_name?(x)}
    end

    def history(name)
      @store.history(name)
    end
  end

  class Page
    include ERB::Util
    ERB.new(<<-EOS).def_method(self, 'to_html(text)')
<pre>
<%=h text %>
</pre>
EOS
    def initialize(info)
      info = {} unless info
      text = info[:src] || ''
      author = info[:author] || []
      mtime = info[:mtime] || Time.now
      update(text, author, mtime)
    end
    attr_reader :src, :html, :author, :mtime

    def update(text, author, mtime=Time.now)
      @src = text
      @html = to_html(text)
      author = [author, @author].compact.flatten.uniq #FIXME
      @author = author
      @mtime = mtime
    end

    def to_hash
      {:src => @src, :author => @author, :mtime => @mtime }
    end
  end
end
