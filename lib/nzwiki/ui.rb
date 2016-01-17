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
    end
    attr_reader :book, :store
    attr_accessor :login, :user
    
    def has_username?
      not @user.to_s.empty?
    end
    
    def user=(value)
      @hint = value
      @user = value
    end
    
    def lookup_view(context)
      @base
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
    background: #fef5da;
    color: #000000;
}

.UserTofu {
    background: #eec;
    font-size: 80%;
    width: 100%;
}
</style>
<script language="JavaScript">
function open_edit(x){
document.getElementById(x).style.display = "block";
}
</script>
</head>
<body>
<div class='UserTofu'>
<%= @user.to_html(context) %>
<% if session.has_username? %>
<% unless session.login %><%= @prompt.to_html(context) %><% end %>
<% end %>
</div>
<hr />
<%= @wiki.to_html(context) %>
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
  end
  
  class UserTofu < Tofu::Tofu
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<% unless @session.has_username? %>
<%=form('user', {}, context)%>
プレイヤー名: <input class='enter' type='text' size='8' name='user' value='<%= @session.user %>'/></form>
<% else %>
<%=h @session.user %> さんのターン！<small>(<%=a('change', {}, context)%>名前かえたい</a>)</small>
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
    end
  end
  
  class PromptTofu < Tofu::Tofu
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<p>
<%=form('prompt', {}, context)%>
<%=h @nazo[:question] %><%
  if @nazo[:choose].size == 1
%><input class='enter' type='text' size='40' name='answer' value='' autocomplete='off' autofocus/><%
  else
%><select name='answer' autofocus><%
    @nazo[:choose].sort_by {|x| Integer(x) rescue rand}.each do |x| 
%><option value="<%=h x %>"><%=h x %></option><%
    end
%></select><input class='submit' type='submit' value='OK' /><%
  end
%>
</form>
</p>
EOS
    def initialize(session)
      super(session)
      @nazo = get_nazo
    end
  
    def do_prompt(context, params)
      answer ,= params['answer']
      it = answer.force_encoding('utf-8') if answer
      if @nazo[:choose][0] == it
        @session.login = true
      end
      @nazo = get_nazo
    end
    
    def tofu_id
      'prompt'
    end
    
    def get_nazo
      @session.store.auth_any
    end
  end

  class ListTofu < Tofu::Tofu
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<%
  @session.book.recent_names.each do |name|
    page = @session.book[name]
%><h2><%=h page.author %></h2><%= page.html%><%
  end
%>
EOS
  end
  
  class WikiTofu < Tofu::Tofu
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<% page = get_page(context) %>
<%= page.html %>
<% if @session.login %>
<a href='javascript:open_edit("edit-<%=h tofu_id %>")'>[edit]</a>
<div id='edit-<%=h tofu_id %>' style='display:none;'>
<%= form('text', {}, context) %>
<textarea name='text' rows="15" cols="40"><%=h page.src %></textarea>
<input type='submit' name='ok' value='ok'/>
</form>
</div>
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



