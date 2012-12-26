module Comments
  class ValidationError < StandardError; end
  
  class NoSuchComment < StandardError; end
  
  class NoSuchPost < StandardError; end
end