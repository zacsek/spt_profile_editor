# frozen_string_literal: true

require 'json'
require 'fileutils'

module SptProfileEditor
  class ProfileSaver
    def initialize(profile_object, server_database)
      @profile = profile_object
      @db = server_database
    end

    def save(original_profile_path, target_path)
      # 1. Make a backup of the original file with a timestamp
      if File.exist?(original_profile_path)
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_path = "#{original_profile_path}_backup_#{timestamp}"
        FileUtils.cp(original_profile_path, backup_path)
      end

      # 2. Write the modified profile data back to the file
      # Since @profile.data holds the full hash (including unmodified parts),
      # we can just write it directly.
      File.write(target_path, JSON.pretty_generate(@profile.data, { indent: "\t" }))
    end
  end
end
