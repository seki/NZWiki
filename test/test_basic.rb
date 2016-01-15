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
    assert_equal(@store['hello'][0], 'world')
    @store['hello'] = 'again'
    assert_equal(@store['hello'][0], 'again')
    @store['hello'] = nil
    assert_equal(@store['hello'][0], nil)
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
end
