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
      @enable_login_by_fav = false
      nazo_setup
    end
    attr_reader :book, :store, :nazo, :user, :login_expires

    def login
      @login = false if @login_expires < Time.now
      @login
    end

    def fav=(key)
      return unless login
      @@fav[@user] = key
    end

    def fav?(key)
      @enable_login_by_fav && @@fav[@user] == key
    end
    
    def has_username?
      not @user.to_s.empty?
    end

    def login=(value)
      @login = value
      nazo_setup
      if @login
        @login_expires = Time.now + 300
        @enable_login_by_fav = true
      end
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

    def to_wiki_name(context)
      path = context.req.path_info.dup
      path[0] = '' if path[0] == '/'
      path == '' ? @book.new_page_name : path
    end

    def get_wiki_page(context)
      name = to_wiki_name(context)
      @book[name]
    end

    def get_wiki_history(context)
      name = to_wiki_name(context)
      @book.history(name)
    end

    def move_to_head
      @base.list.do_top(nil, nil)
    end

    def forget_user
      self.fav = nil
      self.login = false
      self.user = ''
      @enable_login_by_fav = false
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
            <h1><a href="/">とちぎポケカ掲示板</a></h1>
            <p class="change_name font"><%= a('change', {}, context) %>なまえをかえる</a></p>
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
            <%= @history.to_html(context) %>
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
      @history = HistoryTofu.new(session)
    end
    attr_reader :prompt, :list

    def do_change(context, params)
      @session.forget_user
    end
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
      <% if @memo %>
        <p><%=h @memo %></p>
      <% end %>
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
      @memo = nil
      @fav = nil
      @prompt_expires = Time.now
    end

    def do_prompt(context, params)
      answer ,= params['answer']
      it = answer.force_encoding('utf-8') if answer
      nazo = @session.nazo.first
      if nazo[:answer].empty? # fav poke
        @fav = it
        if @session.fav?(it)
          @session.login = true
          @memo = nil
        else
          @session.nazo.shift
          @prompt_expires = Time.now + 30
          @memo = "30秒で答えてね"
        end
      elsif @prompt_expires < Time.now
        @session.nazo_setup
        @memo = "時間切れ！"
      elsif nazo[:answer][0] != it
        @session.nazo_setup
        @memo = "えっ？"
      else
        @memo = nil
        @session.nazo.shift
        if @session.nazo.empty?
          @session.login = true
          @session.fav = @fav
        end
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
          <%= page_to_html(context, name) %>
        <% end %>
        <div class="pager">
          <% if @cursor > 0 %>
            <p class="pager_current">いま<%=h @cursor + 1%>ページ</a></p>
            <p class="pager_new"><%= a('top', {}, context)%>はじめから</a></p>
          <% else %>
          <% end %>
            <p class="pager_old"><%= a('more', {}, context)%>ふるいもの</a></p>
        </div>
      <% else %>
        <%= page_to_html(context, @session.to_wiki_name(context)) %>
      <% end %>
    EOS

    ERB.new(<<-EOS).def_method(self, 'page_to_html(context, name)')
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
              <% if @session.listing?(context) %>
                <p class="button">
                  <a href="/<%= name %>">
                    <img src="/img/button_fix.png" alt="なおす">
                  </a>
                </p>
              <% end %>
              <p class="list_entry_img shake-rotate">
                <img src="/img/img<%= entry_kind %>.png">
              </p>
            </div>
          </div>
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
      case page.author.size
      when 1..2
        page.author.join(", ")
      else
        "みんな"
      end
    end

    def page_style(page)
      page.author.size == 1 ? page.mtime.to_i % 3 : 'm'
    end
  end

  class HistoryTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <% unless @session.listing?(context) %>
        <% history = @session.get_wiki_history(context) %>
        <% if history.size > 1 %>
           <div class='history_wrapper list_entry_m'>
              <div class='ListInfo'>
              <p><%=h history.size%> 件の変更があります。</p>
              </div>
              <% history.reverse_each do |rev| %>
                <div class='ListInfo'>
                  <p class="author">
                    <% auth ,= rev[:author] %>
                    <%=h auth %>
                  </p>
                  <p class="time">
                    <%=h rev[:mtime].strftime("%Y-%m-%d %H:%M") %>
                  </p>
                </div>
                <p class="history_text"><%=h rev[:src] %></p>
              <% end %>
          </div>
        <% end %>
        <p class="button"><a href="/"><img src="/img/button_back.png" alt="もどる"></a></p>

      <% end %>
    EOS
  end

  class WikiTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <% page = @session.get_wiki_page(context) %>
      <% if @session.login %>
        <%= form('text', {}, context) %>
          <textarea name='text' placeholder="ここにメッセージをかいてね"><%=h page.src %></textarea>
          <input class='submit' type='submit' name='ok' value='OK'/>
        </form>
      <% end %>
    EOS

    def do_text(context, params)
      return unless @session.login
      begin
        text ,= params['text']
        return if text.nil? || text.empty?
        text = text.force_encoding('utf-8')
        name = @session.to_wiki_name(context)
        @session.book.update(name, text, @session.user)
        @session.move_to_head
      rescue
        p $!
      end
      context.res.set_redirect(WEBrick::HTTPStatus::MovedPermanently,
                               action(context))
    end
  end
end
