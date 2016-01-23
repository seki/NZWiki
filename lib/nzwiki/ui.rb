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
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<html>
<meta name="viewport" content="width=320" /><head>
<title>NZWiki</title>
<style type="text/css" media="screen">
body {
    font-family: Helvetica;
    background: #1c2f56;
    color: #000000;
}

a:link { 
    color: #4b2311;
}
a:visited { 
    color: #4b2311;
}

hr {
    height: 1px;
    border: none;
    border-top: 1px #000000 dotted;
}

.UserTofu {
    background: #D2b469;
    font-size: 80%;
}

.card {
    border-radius: 0.5em;
    border: solid 0.5em #aaa;
    background: #e6d1b7;
    width: -1em;
    color: #000;
}

.card.ListInfo {
    font-size: 30 %;
    color: #eee;
}

</style>
<script language="JavaScript">
function open_edit(x){
document.getElementById(x).style.display = "block";
}
</script>
</head>
<body>
<div class=card>
<div class=ListInfo><%= @user.to_html(context) %></div>
<% if session.has_username? %>
<% if session.login %><%= @wiki.to_html(context) %>
<% else  %><%= @prompt.to_html(context) %><% end %>
<% end %>
</div>
<hr />
<%= @list.to_html(context) %>
</body></html>
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
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<% unless @session.has_username? %>
<%=form('user', {}, context)%>
プレイヤー名: <input class='enter' type='text' size='8' name='user' value='<%= @session.user %>'/></form>
<% else %>
<small><%=h @session.user %> さんのターン！<small>(<%=a('change', {}, context)%>名前かえたい</a>)</small></small>
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
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<% nazo = @session.nazo.first %>
<% if nazo %>
<p>
<%=form('prompt', {}, context)%>
残り<%= @session.nazo.size %>問
<%=h nazo[:question] %><%
  if nazo[:answer].size == 1
%><input class='enter' type='text' size='40' name='answer' value='' autocomplete='off' autofocus/><%
  else
%><select name='answer' autofocus><%
    nazo[:answer].sort_by {|x| Integer(x) rescue rand}.each do |x| 
%><option value="<%=h x %>"><%=h x %></option><%
    end
%></select><input class='submit' type='submit' value='OK' /><%
  end
%>
</form>
</p>
<% end %>
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
  end

  class ListTofu < Tofu::Tofu
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<%
if @session.listing?(context)
  @session.book.recent_names.each do |name|
    page = @session.book[name]
%><div class='card'>
    <div class='ListInfo'><small><%=h page.author %> <%=h page.mtime.strftime("%Y-%m-%d %H:%M:%S") %> <a href="/<%=name%>">書き直す</a></small></div>
    <%= page.html%>
  </div><hr /> <%
  end
else 
  %><small><a href="/">タイムラインへ</a></small><%
end
%>
EOS
  end
  
  class WikiTofu < Tofu::Tofu
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<%
  page = get_page(context)
  unless @session.listing?(context) 
%><%= page.html %><% 
  end 
  if @session.login 
%><div class=ListInfo >
    <a href='javascript:open_edit("edit-<%=h tofu_id %>")'>
      <% if @session.listing?(context) %>ドロー<% else %>編集する<% end %>
    </a>
  </div>
  <div id='edit-<%=h tofu_id %>'style='display:none;'>
    <%= form('text', {}, context) %>
      <textarea name='text' rows="8" cols="40"><%=h page.src %></textarea>
      <p><input type='submit' name='ok' value='OK'/></p>
    </form>
  </div><%
  else
%><p>なぞなぞをといて</p><%
  end %>
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



