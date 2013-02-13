require 'digest/sha1'

require 'date'

require 'rubygems'

require 'rakismet'

require 'json'

require 'rack'

$: << File.expand_path(File.dirname($0)+"/lib")
$: << "."

#require 'config'

module Comments
  
  # Represents a single {Comment},which is related to a single {Post}.
  # Includes {Rakismet::Model} to allow comments to be checked for spam via the
  # Akismet blog spam checking service. 
  # @see http://akismet.com Details of the Akismet spam checking service
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
  
    # Find a comment based on a key (key is a hash of body+author)
    # from the db.
    # @param [String] key the key to look up
    # @raise [NoSuchComment] if the key that was looked up didn't resolve
    # @return [Comment] the key from the database
    def self.find(key)
      db = Redis.new
      raise NoSuchComment unless(db.exists(key))
      comment = db.hgetall(key)
      c = Comment.new(comment)
      # c.meta = JSON.parse(c.meta)
    end
  
    # @return [String] The HTML-escaped post body
    def body
      Rack::Utils.escape_html(@body)
    end
    
    # @return [String] The raw post-body, including potentially-unsafe HTML
    #   entities
    def body!
      @body
    end
    
    # @return [String] The HTML-escaped post author
    def author
      Rack::Utils.escape_html(@author)
    end
    
    # @return [String] The raw author field, including potentially-unsafe HTML
    def author!
      @author
    end
  
    # @param [Hash] fields The data for this comment, including:
    # @option fields [String] :body The HTML post body*
    # @option fields [String] :author The HTML post author*
    # @option fields [String] :email The email of the post author*
    # @option fields [String] :ip The IP address of the submitter*
    # @option fields [Post] :post A Post object representing the comment that
    #   this post is about.
    # @option fields [DateTime] :posted When the comment was made
    # @option fields [Hash] :meta An extra Hash containing arbitrary extra K/V 
    #  pairs
    # @option fields [String] :referrer The HTTP Referrer field
    #  at the time when this post was submitted. (note spelling)*
    #
    # Note that marked fields may be submitted to Akismet when spam checking.
    def initialize(fields={})
      @config = Comments::Config.new
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
      @meta[:referrer] = fields[:referrer] || fields["referrer"] || nil
    end
  
    # Returns the database storage key for this post. The key is a function of
    # SHA1SUM(@body+@author)
    def key
      Digest::SHA1.hexdigest(@body+@author)
    end
 
    # Inserts this Comment into the Redis backing store, as a Hash
    # @raise [ValidationError] if the post is invalid. See {#validation_errors}
    #  and {#is_valid?}
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
    
    # Saves the Comment, ignoring validation errors. Note, if @body or @author
    # aren't present, this will potentially cause hash collisions because {#key}
    # won't make sense.
    def save!
      begin
        save
      rescue ValidationError
      end
    end
  
    # All of the problems which would prevent this comment from being saved.
    # Referenced by {#is_valid?}.
    # @return [Array<String>] an array of problems.
    def validation_errors
      errors = []
      errors << "NoEmail" unless email != nil and email.length > 0
      errors << "NoBody" if body.length < 3
      errors << "NoAuthor" if author.length < 3
      errors << "NoIP" unless /[0-9a-fA-F\:\.]+/ =~ ip
      errors
    end
  
    # If this is a valid post.
    # @return [boolean] Whether or not this post has any validation errors.
    def is_valid?
      validation_errors.length == 0
    end
    
    # HTTP Referer at the time when this post was submitted.
    def referrer
      @meta[:referrer]
    end
    
    def <=>(other)
      @posted <=> other.posted
    end
    
    # Delete this comment, and potentially delete it's reference from the linked
    # {Post}.
    def destroy
      if post
        post.delete_comment(self)
      end
      db.del key
    end
    
    # @return [String] The string representation of this object
    def to_s
      "<Comments::Comment @author=#{@author} @body=#{@body}"+
      " @key=#{key} @posted=#{@posted}, @meta=#{@meta}>"
    end
    
    # Test whether other} is equal to self.
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
