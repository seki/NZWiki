require 'test/unit'
require '../lib/nzwiki.rb'

class TestNZStore < Test::Unit::TestCase
  def setup
    @drip = Drip.new(nil)
    @store = NZWiki::Store.new(@drip, 'test')
    @store = NZWiki::Store.new(@drip, 'test')
  end

  def test_page
    assert_equal(@store['hello'], nil)
    @store['hello'] = 'world'
    assert_equal(@store['hello'], 'world')
    @store['hello'] = 'again'
    assert_equal(@store['hello'], 'again')
    @store['hello'] = nil
    assert_equal(@store['hello'], nil)
  end

  def test_auth_create
    assert_equal(@store.auth_create, 1)
    assert_equal(@store.auth_create, 2)
    assert_equal(@store.auth_create, 3)
  end

  def test_auth_set
    key = @store.auth_create
    @store.auth_set(key, 'hello')
    @store.auth_set(key, 'hello, world')
    key = @store.auth_create
    @store.auth_set(key, 'quit')
    key = @store.auth_create
    @store.auth_set(key, 'again')
  end

  def test_auth_any
    assert_equal(@store.auth_any, nil)

    assert_equal(@store.auth_create, 1)
    assert_equal(@store.auth_create, 2)
    assert_equal(@store.auth_create, 3)
    
    @store.auth_set(1, '1')
    @store.auth_set(2, '2')
    @store.auth_set(3, '3')

    # FIXME
    10.times do
      assert(['1', '2', '3'].include?(@store.auth_any))
    end
  end

  def test_next_page
    @store['hello'] = 'world'
    @store['hello'] = 'again'
    @store['again'] = 'hello'
    @store['zz'] = 'hello'
    @store['hello'] = nil

    assert_equal(@store.next_page(''), 'again')
    assert_equal(@store.next_page('again'), 'hello')
    assert_equal(@store.next_page('hello'), 'zz')
    assert_equal(@store.next_page('zz'), nil)

    @store['zzz'] = 'hello'

    assert_equal(@store.next_page('zz'), 'zzz')
    assert_equal(@store.next_page('zzz'), nil)
    
    assert_equal(@store.each_page.to_a.reverse, ['again', 'hello', 'zz', 'zzz'])
  end
end

class TestNZBook < Test::Unit::TestCase
  def setup
    @drip = Drip.new(nil)
    @store = NZWiki::Store.new(@drip, 'test')
    @book = NZWiki::Book.new(@store)
  end
  
  def test_order
    a = []

    a << @book.new_page_name
    @book.update(a.last, 'hello', 'foo')

    a << @book.new_page_name
    @book.update(a.last, 'world', 'foo')

    ary = @book.recent_names.to_a
    assert_equal(ary, [a[1], a[0]])

    @book.update(a[0], 'hello', 'baz')
    assert_equal(@book.recent_names.to_a, [a[1], a[0]])

    new_book = NZWiki::Book.new(@store)
    assert_equal(new_book.recent_names.to_a, [a[1], a[0]])
  end
end
