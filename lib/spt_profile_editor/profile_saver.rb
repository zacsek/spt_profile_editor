# frozen_string_literal: true

require 'json'

module SptProfileEditor
  class ProfileSaver
    def initialize(profile_object, server_database)
      @profile = profile_object
      @db = server_database
    end

    def save(original_profile_path, target_path)
      # 1. Read the original file
      original_data = JSON.parse(File.read(original_profile_path))

      # 2. Deep merge the changes from the @profile object back into the original data.
      # This is a placeholder for the more complex, surgical updates in the C# version.
      # A simple merge is not enough, but it's a starting point.
      # For a true port, each `Write...` method from the C# version needs to be implemented here.
      
      # Example of surgical update:
      original_data['characters']['pmc']['Info']['Level'] = @profile.pmc.level

      # A more complete implementation would go here, modifying `original_data`
      # based on all changes in `@profile`.

      # 3. Write the modified hash back to the file
      File.write(target_path, JSON.pretty_generate(original_data, { indent: "\t" }))
    end
  end
end
