require 'yaml'

module Comments
  class Config
    attr_reader :config
  
    def initialize(configfile='config.yml')
      @config = YAML.load_file(configfile)
    end
  end
end