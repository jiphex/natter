require 'digest/sha1'

require 'rubygems'
# require 'bundler/setup'

require 'json'

require 'rack'

require 'rakismet'

module Comments
  class Comment
  
    include Rakismet::Model
    
    Rakismet.key = "79fabe58dd76"
    Rakismet.url = "http://drax2.tlyk.eu"
    Rakismet.host = "rest.akismet.com"
  
    attr_accessor :body,:author, :email, :post, :meta
    attr_reader :ip, :posted
    
    alias :author_email :email
    alias :content :body
    alias :user_ip :ip
  
    def self.find(key)
      db = Redis.new
      raise NoSuchComment unless(db.exists(key))
      comment = db.hgetall(key)
      c = Comment.new(comment)
      # c.meta = JSON.parse(c.meta)
    end
  
    def body
      Rack::Utils.escape_html(@body)
    end
    
    def body!
      @body
    end
    
    def author
      Rack::Utils.escape_html(@author)
    end
    
    def author!
      @author
    end
  
    def initialize(fields={})
      @body = fields[:body] || fields["body"] || nil
      @author = fields [:author] || fields["author"] || nil
      @email = fields[:email] || fields['email'] || nil
      @ip = fields[:ip] || fields["ip"] || nil
      @post = fields[:post] || nil
      @posted = fields[:posted] || DateTime.now
      fpost = fields["post"] || fields[:post]
      begin
        if fpost and Comments::Post.find(fpost)
          @post_key = fpost
        end
      rescue Comments::NoSuchPost
        # then the comment's post field points at a bad post, diddums
      end
      passed_meta = fields[:meta] or fields["meta"]
      if passed_meta
        @meta = passed_meta
      else
        @meta = fields
      end
    end
  
    def key
      Digest::SHA1.hexdigest(@body+@author)
    end
 
    def save
      raise ValidationError unless is_valid?
      db.multi do
        db.hset key, "body", @body
        db.hset key, "author", @author
        db.hset key, "ip", @ip
        db.hset key, "email", @email
        db.hset key, "meta", @meta.to_json
        db.hset key, "post", @post_key
        if post != nil
          @post.comments << self
          @post.save
        end
      end
    end
    
    def save!
      begin
        save
      rescue ValidationError
      end
    end
  
    def validation_errors
      errors = []
      errors << "NoEmail" unless email != nil and email.length > 0
      errors << "NoBody" if body.length < 3
      errors << "NoAuthor" if author.length < 3
      errors << "NoIP" unless /[0-9a-fA-F\:\.]+/ =~ ip
      errors
    end
  
    def is_valid?
      validation_errors.length == 0
    end
    
    def referrer
      @meta[:referrer]
    end
    
    def id
    end
    
    def <=>(other)
      @posted <=> other.posted
    end
    
    def destroy
      if post
        post.delete_comment(self)
      end
      db.del key
    end
    
    def to_s
      "<Comments::Comment @author=#{@author} @body=#{@body}"+
      " @key=#{key} @posted=#{@posted}, @meta=#{@meta}>"
    end
    
    def ==(other)
      return false unless other.key == key
      # return false unless other.posted == posted
      return true
    end
    
    def post
      return nil if @post_key == nil
      begin
        p = Post.find(@post_key)
        return p
      rescue Comments::NoSuchPost
        return nil
      end
    end
    
    def post=(pozt)
      @post_key = pozt.ckey
    end
  
    private
  
    def db
      return @db if @db
      @db = Redis.new
    end
  end
end