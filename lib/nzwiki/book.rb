# -*- coding: utf-8 -*-
require 'kramdown'
require 'drip'

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
      (Time.local(2016) .. Time.now).include?(time)
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
  end

  class Page
    def initialize(info)
      info = {} unless info
      text = info[:src] || ''
      author = info[:author] || 'unknown'
      mtime = info[:mtime] || Time.now
      update(text, author, mtime)
    end
    attr_reader :src, :html, :warnings, :author, :mtime

    def update(text, author, mtime=Time.now)
      @src = text
      document = Kramdown::Document.new(text)
      @html = document.to_html
      @warnings = document.warnings
      @author = author
      @mtime = mtime
    end

    def to_hash
      {:src => @src, :author => @author, :mtime => @mtime }
    end
  end
end
