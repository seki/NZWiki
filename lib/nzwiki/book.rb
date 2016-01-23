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

    def recent_names(sz=10)
      @store.each_page.to_a
    end
  end

  class Page
    def initialize(info)
      info = {} unless info
      text = info[:src] || ''
      author = info[:author] || 'unknown'
      mtime = info[:mtime] || Time.now
      update(text, author)
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
      {:src => @src, :author => @author }
    end
  end
end
