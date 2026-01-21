# frozen_string_literal: true

module SptProfileEditor
  class ProfileLoader
    def self.load(file_path, database)
      raise "Profile file not found: #{file_path}" unless File.exist?(file_path)
      raw_json = File.read(file_path)
      data_hash = JSON.parse(raw_json)
      Profile.new(data_hash, database)
    end
  end
end
