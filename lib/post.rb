module Comments

  # Used to wire-up the #{<<} method of a {Post}'s list of {Comment}s to the
  # {Comment}.#{add_post} method.
  class CommentSet < Array
    def initialize(post)
      @sender = post
    end
    alias :<< :push
    def <<(komment)
      @sender.add_comment(komment)
    end
  end

  class Post
    
    attr_reader :ckey
  
    def self.find(ckey)
      kk = "comment:"+ckey
      db = Redis.new
      raise NoSuchPost unless db.exists(kk)
      raise StandardError unless db.type(kk) == "list"
      Post.new(kk)
    end
  
    def initialize(ckey)
      @ckey = ckey
      # @comments = []
    end
    
    def to_s
      @ckey
    end
  
    # @!attribute [rw] comments
    # The {Comment}s for this post.
    def comments(start=0, cend=10)
      fromdb = db.lrange(@ckey, start, cend).map do |crd|
        begin
          Comment.find(crd)
        rescue NoSuchComment
          # garbage collect
          db.lrem(@ckey, 1, crd)
          next
        end
      end.compact
      CommentSet.new(self).concat(fromdb)
    end
    
    # def save
      # comments.uniq.each do |c|
        # db.lpush(@ckey, c.key)
      # end
    # end
    
    def add_comment(komment)
      if komment.is_a?(Enumerable)
        komment.each do |i|
          db.lpush(@ckey, i.key)
        end
      end
      unless komment.is_a? Comment
        raise ArgumentError, "Not a comment"
      end
      komment.save
      db.lpush(@ckey, komment.key)
    end
  
    def delete_comment(comment)
      if comment.is_a?(Comment)
        db.lrem @ckey, 0, comment.key
      elsif comment.is_a? String
        db.lrem @ckey, 0, comment_key
      else
        raise ArgumentError
      end
    end
  
    private
  
    def db
      return @db if @db
      @db = Redis.new
    end 
  
  end
end
