# -*- coding: utf-8 -*-
require 'kramdown'

module NZWiki
  class Book
    def initialize(store)
      @monitor = Monitor.new
      @pages = {}
      @store = store
    end

    def [](name)
      @monitor.synchronize do
        @pages[name] || Page.new(name)
      end
    end

    def update(name, src, author)
      @monitor.synchronize do
        page = self[name]
        @pages[name] = page
        page.update(src, author)
      end
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
  end
end
