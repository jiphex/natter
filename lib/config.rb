require 'yaml'

module Comments
  class Config
    attr_reader :config
  
    def [](key)
      @config[key]
    end
  
    def initialize(configfile='config.yml')
      @config = YAML.load_file(configfile)
    end
  end
end