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
        @pages[name] || Page.new(name)
      end
    end

    def update(name, src, author)
      @monitor.synchronize do
        page = self[name]
        @pages.delete(name)
        @pages[name] = page
        @store[name] = page.to_hash
        page.update(src, author)
      end
    end

    def recent_names(sz=10)
      @store.each_page.to_a
    end
  end

  class Page
    def initialize(name)
      @name = name
      update("# New Page\n\nan empty page. edit me.", "unknown")
    end
    attr_reader :name, :src, :html, :warnings, :author

    def update(text, author)
      @src = text
      document = Kramdown::Document.new(text)
      @html = document.to_html
      @warnings = document.warnings
      @author = author
    end

    def to_hash
      {:src => @src, :author => @author }
    end
  end
end
