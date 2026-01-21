# frozen_string_literal: true

require_relative "spt_profile_editor/version"
require_relative "spt_profile_editor/configuration"
require_relative "spt_profile_editor/server_database"
require_relative "spt_profile_editor/profile"
require_relative "spt_profile_editor/profile_loader"
require_relative "spt_profile_editor/profile_saver"


module SptProfileEditor
  class Error < StandardError; end

  class Editor
    attr_reader :profile

    def initialize(server_path = nil)
      SptProfileEditor.configure do |config|
        config.server_path = server_path if server_path
      end

      path = SptProfileEditor.configuration.server_path
      raise "SPT Server Path not found. Please set SPT_PATH environment variable or pass the path to the constructor." unless path

      @db = ServerDatabase.new(path)
      puts "Server database loaded from #{path}"
    end

    def load_profile(profile_name)
        profile_path = File.join(SptProfileEditor.configuration.server_path, 'user', 'profiles', "#{profile_name}.json")
        @profile_path = profile_path
        @profile = ProfileLoader.load(profile_path, @db)
        puts "Loaded profile for '#{@profile.pmc.nickname}' (Level #{@profile.pmc.level})"
        @profile
    end

    def save_profile(target_path = nil)
      raise "No profile loaded." unless @profile

      target_path ||= @profile_path
      saver = ProfileSaver.new(@profile, @db)
      saver.save(@profile_path, target_path)
      puts "Profile saved to #{target_path}"
    end

    def search_item(name)
      @db.search_items_by_name(name)
    end
  end
end
