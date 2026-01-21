# frozen_string_literal: true

module SptProfileEditor
  class Configuration
    attr_accessor :server_path

    def initialize
      @server_path = ENV['SPT_PATH']
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
