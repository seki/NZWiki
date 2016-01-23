# -*- coding: utf-8 -*-
require 'tofu'

module NZWiki
  class NZSession < Tofu::Session
    @@book = nil
    @@store = nil

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
      nazo_setup
    end
    attr_reader :book, :store, :nazo, :login, :user
    
    def expires
      Time.now + 5 * 60
    end

    def has_username?
      not @user.to_s.empty?
    end

    def login=(value)
      @login = value
      nazo_setup
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
    end
  end

  class BaseTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <html>
        <head>
          <meta name="viewport" content="width=640" />
          <title>NZWiki</title>
          <link href="/css/nzwiki.css" rel="stylesheet">
        </head>
        <body>
          <div id="wrapper">
            <div class='UserTofu'>
              <%= @user.to_html(context) %>
              <% if session.has_username? %>
                <% unless session.login %>
                  <%= @prompt.to_html(context) %>
                <% end %>
              <% end %>
              <%= @wiki.to_html(context) %>
            </div>
            <p class="UserTofuImg">
              <img src="/img/img.png">
            </p>
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
          <p>プレイヤー名</p>
          <input class='enter' type='text' name='user' value='<%= @session.user %>'/>
        </form>
      <% else %>
        <p>
          <%=h @session.user %> さんのターン！
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
          <% if nazo[:answer].size == 1 %>
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
    end

    def do_prompt(context, params)
      answer ,= params['answer']
      it = answer.force_encoding('utf-8') if answer
      nazo = @session.nazo.first
      if nazo[:answer][0] == it
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
        <% @session.book.recent_names.each do |name| %>
          <% page = @session.book[name] %>
          <div class='list_entry_wrapper'>
            <div class='list_entry'>
              <div class='ListInfo'>
                <p class="author">
                  <%=h page.author %>
                </p>
                <p class="time">
                  <%=h page.mtime.strftime("%Y-%m-%d %H:%M") %>
                </p>
              </div>
              <%= page.html %>
              <p class="button">
                <a href="/<%= name %>">
                  <img src="/img/button.png">
                </a>
              </p>
            </div>
            <p>
              <img src="/img/img.png">
            </p>
          </div>
        <% end %>
      <% else %>
        <small>
          <a href="/">タイムラインへ</a>
        </small>
      <% end %>
    EOS
  end

  class WikiTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
      <% page = get_page(context) %>
      <% unless @session.listing?(context) %>
        <%= page.html %>
      <% end %>
      <% if @session.login %>
        <%= form('text', {}, context) %>
          <textarea name='text' placeholder="ここにメッセージをかいてね"><%=h page.src %></textarea>
          <input class='submit' type='submit' name='ok' value='OK'/>
        </form>
        <p>(<%= a('change', {}, context) %>名前かえたい</a>)</p>
      <% end %>
    EOS

    def to_name(context)
      path = context.req.path_info.dup
      path[0] = '' if path[0] == '/'
      path == '' ? @session.book.new_page_name : path
    end

    def do_text(context, params)
      return unless @session.login
      begin
        text ,= params['text']
        return if text.nil? || text.empty?
        text = text.force_encoding('utf-8')
        @session.book.update(to_name(context), text, @session.user)
      rescue
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
