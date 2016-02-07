# -*- coding: utf-8 -*-
require 'tofu'
require 'nzwiki/enum'

module NZWiki
  class NZSession < Tofu::Session
    @@book = nil
    @@store = nil
    @@fav = {}

    def self.book=(book)
      @@book = book
    end

    def self.store=(store)
      @@store = store
    end

    def initialize(bartender, hint='')
      super
      @user = @hint.to_s.dup.force_encoding('utf-8')
      @book = @@book
      @store = @@store
      @base = BaseTofu.new(self)
      @login = false
      @login_expires = Time.now
      nazo_setup
    end
    attr_reader :book, :store, :nazo, :user, :login_expires

    def login
      @login = false if @login_expires < Time.now
      @login
    end
    
    def has_username?
      not @user.to_s.empty?
    end

    def login=(value)
      @login = value
      nazo_setup
      @login_expires = Time.now + 300 if @login
    end
    
    def user=(value)
      @hint = value
      @user = value
      nazo_setup
    end

    def lookup_view(context)
      @base
    end

    def listing?(context)
      context.req.path_info == '/'
    end
    
    def nazo_setup
      @nazo = @store.auth_any(3)
      @nazo.unshift({:question => "#{user} さんのすきなポケモンは？",
                      :answer => []})
    end
  end

  class BaseTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <html>
        <head>
          <meta name="viewport" content="width=640" />
          <title>とちぎポケカ掲示板</title>
          <link href="/css/css.css" rel="stylesheet">
        </head>
        <body>
          <div id="wrapper">
            <h1>とちぎポケカ掲示板</h1>
            <div class='UserTofu'>
              <%= @user.to_html(context) %>
              <% if session.has_username? %>
                <% unless session.login %>
                  <%= @prompt.to_html(context) %>
                <% end %>
              <% end %>
              <%= @wiki.to_html(context) %>
              <p class="topimg shake-slow">
                <img src="/img/topimg.png" class="shake">
              </p>
            </div>
            <%= @list.to_html(context) %>
          </div>
        </body>
      </html>
    EOS

    def initialize(session)
      super(session)
      @user = UserTofu.new(session)
      @prompt = PromptTofu.new(session)
      @wiki = WikiTofu.new(session)
      @list = ListTofu.new(session)
    end
    attr_reader :prompt
  end

  class UserTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <% unless @session.has_username? %>
        <%= form('user', {}, context) %>
          <p class="font">プレイヤー名</p>
          <input class='enter' type='text' name='user' value='<%= @session.user %>'/>
        </form>
      <% else %>
        <p class="font">
          <%=h @session.user %>さんのターン！
        </p>
      <% end %>
    EOS

    def initialize(session)
      super(session)
    end

    def do_change(context, params)
      @session.login = false
      @session.user = ''
    end

    def do_user(context, params)
      user ,= params['user']
      user = user.force_encoding('utf-8') if user
      @session.login = false
      @session.user = user
      context.res.set_redirect(WEBrick::HTTPStatus::MovedPermanently,
                               action(context))
    end
  end

  class PromptTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <p>
        <% nazo = @session.nazo.first %>
        <%= form('prompt', {}, context) %>
          <p><%=h nazo[:question] %></p>
          <% if nazo[:answer].size <= 1 %>
            <input class='enter' type='text' name='answer' value='' autocomplete='off' autofocus/>
          <% else %>
            <select name='answer' autofocus>
              <% nazo[:answer].sort_by {|x| Integer(x) rescue rand}.each do |x| %>
                <option value="<%=h x %>"><%=h x %></option>
              <% end %>
            </select>
            <input class='submit' type='submit' value='OK' />
          <% end %>
        </form>
      </p>
    EOS

    def initialize(session)
      super(session)
      @prompt_expires = Time.now
    end

    def do_prompt(context, params)
      answer ,= params['answer']
      it = answer.force_encoding('utf-8') if answer
      nazo = @session.nazo.first
      if nazo[:answer].empty?
        @memo = it
        @session.nazo.shift
        @prompt_expires = Time.now + 30
      elsif nazo[:answer][0] == it and @prompt_expires > Time.now
        @session.nazo.shift
        if @session.nazo.empty?
          @session.login = true
        end
      else
        @session.nazo_setup
      end
      context.res.set_redirect(WEBrick::HTTPStatus::MovedPermanently,
                               action(context))
    end

    def tofu_id
      'prompt'
    end

    def get_nazo
      @session.store.auth_any
    end
  end

  class ListTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <% if @session.listing?(context) %>
        <% @session.book.recent_names.slice(@cursor * 7, 7) do |name| %>
          <% page = @session.book[name] %>
          <% entry_kind = page_style(page) %>
          <div class='list_entry_wrapper list_entry_<%= entry_kind %>'>
            <div class='list_entry'>
              <div class='ListInfo'>
                <p class="author">
                  <%=h author(page) %>
                </p>
                <p class="time">
                  <%=h page.mtime.strftime("%Y-%m-%d %H:%M") %>
                </p>
              </div>
              <%= page.html %>
              <p class="button">
                <a href="/<%= name %>">
                  <img src="/img/button_fix.png" alt="なおす">
                </a>
              </p>
              <p class="list_entry_img shake-rotate">
                <img src="/img/img<%= entry_kind %>.png">
              </p>
            </div>
            
          </div>
        <% end %>
        <% if @cursor > 0 %>
          いま<%=h @cursor + 1%> ページ</a>
          <%= a('top', {}, context)%>はじめから</a>
        <% else %>
        <% end %>
        <%= a('more', {}, context)%>もっとふるいの</a>
      <% else %>
          <p class="button"><a href="/"><img src="/img/button_back.png" alt="もどる"></a></p>
      <% end %>
    EOS

    def initialize(session)
      super(session)
      @cursor = 0
    end

    def do_more(context, params)
      @cursor += 1
    end

    def do_top(context, params)
      @cursor = 0
    end

    def author(page)
      page.author.join(", ")
    end

    def page_style(page)
      page.author.size == 1 ? page.mtime.to_i % 2 + 1 : 0
    end
  end

  class WikiTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <% page = get_page(context) %>
      <% unless @session.listing?(context) %>
        <div class="page"><%= page.html %></div>
      <% end %>
      <% if @session.login %>
        <%= form('text', {}, context) %>
          <textarea name='text' placeholder="ここにメッセージをかいてね"><%=h page.src %></textarea>
          <input class='submit' type='submit' name='ok' value='OK'/>
        </form>
      <% end %>
      <p class="change_name font"><%= a('change', {}, context) %>なまえをかえる</a></p>
    EOS

    def to_name(context)
      path = context.req.path_info.dup
      path[0] = '' if path[0] == '/'
      path == '' ? @session.book.new_page_name : path
    end

    def do_change(context, params)
      @session.user = nil
      @session.login = false
    end

    def do_text(context, params)
      return unless @session.login
      begin
        text ,= params['text']
        return if text.nil? || text.empty?
        text = text.force_encoding('utf-8')
        @session.book.update(to_name(context), text, @session.user)
      rescue
        p $!
      end
      context.res.set_redirect(WEBrick::HTTPStatus::MovedPermanently,
                               action(context))
    end

    def get_page(context)
      name = to_name(context)
      @session.book[name]
    end
  end
end
