require 'test/unit'

require 'rubygems'

require 'redis'

$: << ".."

require 'lib/post'
require 'lib/comment'
require 'lib/errors'

class TestComment < Test::Unit::TestCase

  TEST_BODY="This is a test comment"
  TEST_AUTHOR="Testing"
  TEST_EMAIL="test@example.com"
  TEST_IP="1.2.3.4"

  def setup
  end
  
  def setup
    @c = Comments::Comment.new(
    :body=>TEST_BODY,
    :author=>TEST_AUTHOR,
    :email=>TEST_EMAIL,
    :ip=>TEST_IP)
    
    # if db.exists @c.key
      # db.del @c.key
    # end
  end
  
  def test_initializers
    assert_equal(TEST_BODY, @c.body)
    assert_equal(TEST_AUTHOR, @c.author)
    assert_equal(TEST_EMAIL, @c.email)
    assert_equal(TEST_IP, @c.ip)
  end
  
  def test_htmlentities
    @c.body = "<script>alert('x');</script>"
    assert_equal("&lt;script&gt;alert(&#x27;x&#x27;);&lt;&#x2F;script&gt;", @c.body)
    # assert_no_match /<script/, @c.body
  end
  
  def test_key
    assert_equal('1fdbe65c03706501c984254cbdfb9d8f349830ae', @c.key)
  end
  
  def test_validations
    bad_comment = Comments::Comment.new
    assert(!bad_comment.is_valid?)
    assert(bad_comment.validation_errors.length > 0)
    assert_raise Comments::ValidationError do
      bad_comment.save
    end
  end
  
  def test_save
    assert(!db.exists(@c.key))
    @c.save
    assert(db.exists(@c.key), "Couldn't save #{@c.inspect}")
    c_from_db = Comments::Comment.find(@c.key)
    assert_equal(@c, c_from_db)
  end
  
  def test_delete
    @c.save
    assert(db.exists(@c.key))
    @c.destroy
    assert(!db.exists(@c.key))
  end
  
  def test_akismet
    @c.author = "viagra-test-123" # special akismet test string
    assert(@c.spam?)
    # can't test for not-spam really
    # @c.author = "notspam-123"
    # assert(!@c.spam?)
  end
  
  private
  
  def db
    require 'redis'
    return @db if @db
    @db = Redis.new
    begin
      @db.ping
    rescue Redis::CannotConnectError
      skip 'Couldn\'t connect to local Redis DB'
    end
    @db
  end
end
