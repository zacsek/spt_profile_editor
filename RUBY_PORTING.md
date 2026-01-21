# Porting SPT-AKI Profile Editor to Ruby

This document outlines a strategy for porting the core, non-UI functionality of the C# SPT-AKI Profile Editor to a Ruby gem. The goal is to create a library that can programmatically read, modify, and save SPT-AKI profile files.

## 1. Project Analysis

The C# project is a WPF application that uses the MVVM pattern. The core logic is well-separated from the UI.

- **Data Format**: The profile files are **JSON**.
- **Core Dependency**: The project heavily relies on `Newtonsoft.Json` for all JSON operations. The Ruby equivalent is the built-in `json` gem.
- **Saving Mechanism**: The editor does **not** simply overwrite the profile with its in-memory representation. It reads the original JSON file into a mutable `JObject`, surgically modifies specific sections of this object, and then writes the modified `JObject` back to a file. This is done to preserve any data in the profile that the editor doesn't explicitly handle. **This is a critical detail to replicate.**
- **Data Models**: The core data structures are defined in `SPT-AKI Profile Editor/Core/ProfileClasses/`. The key classes are:
    - `Profile.cs`: The root object of the profile file.
    - `Character.cs`: Represents a PMC or Scav character, containing the bulk of the editable data (info, health, skills, quests, inventory, etc.). This class also contains many of the high-level editing methods (e.g., `SetAllTradersMax`).
    - `ProfileSaver.cs`: Contains the logic for the complex save mechanism described above.
- **External Game Data**: The editor's logic depends on external game data loaded from the SPT-AKI server installation (e.g., item definitions, quest trees, trader data). This data is loaded into a global `AppData.ServerDatabase` object and is referenced throughout the code. The Ruby gem will need a similar mechanism to access this data.

## 2. Ruby Gem Implementation Strategy

### Step 1: Gem Scaffolding

Create a new Ruby gem. The file structure should be standard.

```bash
bundle gem spt_aki_profile_editor
```

### Step 2: Configuration and Server Data

The gem needs to know where the SPT-AKI server files are to load the necessary game data.

1.  **Create a `Configuration` class:**

    ```ruby
    # lib/spt_aki_profile_editor/configuration.rb
    module SptAkiProfileEditor
      class Configuration
        attr_accessor :server_path

        def initialize
          @server_path = nil
        end
      end

      def self.configuration
        @configuration ||= Configuration.new
      end

      def self.configure
        yield(configuration)
      end
    end
    ```

2.  **Create a `ServerDatabase` class:** This class will be responsible for loading and providing access to the server data, mimicking the C# `AppData.ServerDatabase`.

    ```ruby
    # lib/spt_aki_profile_editor/server_database.rb
    require 'json'

    module SptAkiProfileEditor
      class ServerDatabase
        attr_reader :items, :quests, :traders # etc.

        def initialize(server_path)
          # Load items database
          items_path = File.join(server_path, 'Aki_Data', 'Server', 'database', 'templates', 'items.json')
          @items = JSON.parse(File.read(items_path))

          # Load quests data
          quests_path = File.join(server_path, 'Aki_Data', 'Server', 'database', 'templates', 'quests.json')
          @quests = JSON.parse(File.read(quests_path))

          # ... load other necessary database files (traders, locales, etc.)
        end
      end
    end
    ```

### Step 3: Replicate Data Models

Replicate the C# data model classes in Ruby. You can choose between using simple `Hash` objects or creating dedicated classes. Using classes is recommended for clarity and to encapsulate logic.

1.  **Create `Profile` and `Character` classes:**

    ```ruby
    # lib/spt_aki_profile_editor/profile.rb
    require 'json'

    module SptAkiProfileEditor
      class Profile
        attr_accessor :characters, :user_builds, :customisation_unlocks

        def initialize(data_hash)
          @characters = CharacterSet.new(data_hash['characters'])
          # ... initialize other properties
        end

        # High-level feature methods can go here
        def set_all_skills_to_max
          @characters.pmc.set_all_skills(99999) # Example
          @characters.scav.set_all_skills(99999) # Example
        end
      end

      class CharacterSet
        attr_accessor :pmc, :scav
        def initialize(hash)
          @pmc = Character.new(hash['pmc'])
          @scav = Character.new(hash['scav'])
        end
      end

      class Character
        attr_accessor :info, :health, :skills, :quests # etc.

        def initialize(data_hash)
          # Initialize all the character properties from the hash
          @info = data_hash['Info']
          @health = data_hash['Health']
          # ...
        end

        def set_all_skills(value)
          # Logic to modify the @skills data
        end
      end
    end
    ```

### Step 4: Implement the Loading and Saving Logic

This is the most critical part.

1.  **Create a `ProfileLoader`:** This class will read the JSON and instantiate your Ruby `Profile` object.

    ```ruby
    # lib/spt_aki_profile_editor/profile_loader.rb
    module SptAkiProfileEditor
      class ProfileLoader
        def self.load(file_path)
          raw_json = File.read(file_path)
          data_hash = JSON.parse(raw_json)
          Profile.new(data_hash)
        end
      end
    end
    ```

2.  **Create a `ProfileSaver`:** This class will replicate the logic from the C# `ProfileSaver.cs`.

    ```ruby
    # lib/spt_aki_profile_editor/profile_saver.rb
    require 'json'

    module SptAkiProfileEditor
      class ProfileSaver
        def initialize(profile_object, server_database)
          @profile = profile_object
          @db = server_database
        end

        def save(original_profile_path, target_path)
          # 1. Read the original file
          original_data = JSON.parse(File.read(original_profile_path))

          # 2. Modify the hash section by section
          # This is a simplified example of WriteCharacterInfo
          pmc_token = original_data['characters']['pmc']
          pmc_token['Info']['Nickname'] = @profile.characters.pmc.info['Nickname']
          pmc_token['Info']['Level'] = @profile.characters.pmc.info['Level']

          # Replicate every 'Write...' method from the C# ProfileSaver
          # write_quests(original_data)
          # write_hideout(original_data)
          # write_stash(original_data)
          # ... and so on. The order is important!

          # 3. Write the modified hash back to the file
          File.write(target_path, JSON.pretty_generate(original_data, { indent: "\t" }))
        end
      end
    end
    ```

### Step 5: Create a Main Interface

Create a top-level class or module to provide a simple API for users of the gem.

```ruby
# lib/spt_aki_profile_editor.rb
require_relative 'spt_aki_profile_editor/configuration'
require_relative 'spt_aki_profile_editor/server_database'
require_relative 'spt_aki_profile_editor/profile_loader'
require_relative 'spt_aki_profile_editor/profile_saver'
require_relative 'spt_aki_profile_editor/profile'

module SptAkiProfileEditor
  class Editor
    def initialize(server_path)
      SptAkiProfileEditor.configure { |config| config.server_path = server_path }
      @db = ServerDatabase.new(server_path)
    end

    def load_profile(profile_path)
      @profile_path = profile_path
      @profile = ProfileLoader.load(profile_path)
    end

    def profile
      @profile
    end

    def save_profile(target_path = nil)
      target_path ||= @profile_path
      saver = ProfileSaver.new(@profile, @db)
      saver.save(@profile_path, target_path)
      puts "Profile saved to #{target_path}"
    end
  end
end
```

### Step 6: Example Usage Script

Finally, create an example script to demonstrate how to use the gem.

```ruby
#!/usr/bin/env ruby

# /bin/configure_profile.rb

require 'spt_aki_profile_editor'

# --- Configuration ---
SERVER_PATH = '/path/to/spt_aki_server'
PROFILE_PATH = File.join(SERVER_PATH, 'user', 'profiles', 'your_profile_id.json')
# ---

# 1. Initialize the editor with the server path
editor = SptAkiProfileEditor::Editor.new(SERVER_PATH)

# 2. Load the profile
profile = editor.load_profile(PROFILE_PATH)
puts "Loaded profile for #{profile.characters.pmc.info['Nickname']}"

# 3. Modify the profile
# Example: Set PMC level to 50
profile.characters.pmc.info['Level'] = 50
puts "Set PMC level to 50."

# Example: Use a high-level method
profile.set_all_skills_to_max
puts "Set all skills to max."

# 4. Save the changes
editor.save_profile # Saves back to the original file
# or editor.save_profile('/path/to/new_profile.json')

puts "Done."
```

## Summary of Porting Task

1.  **Setup**: Create the gem, `Configuration`, and `ServerDatabase` to handle game data.
2.  **Data Models**: Recreate the C# classes from `Core/ProfileClasses` as Ruby classes to hold profile data.
3.  **Implement `ProfileSaver`**: This is the most complex part. You must carefully reimplement the logic from `ProfileSaver.cs`, ensuring you read the original file, modify it in memory as a Hash, and write it back, respecting the order of operations.
4.  **Implement Business Logic**: Port the high-level methods from `Character.cs` (like `SetAllTradersMax`, etc.) into your Ruby `Character` or `Profile` class.
5.  **API**: Build a simple top-level API (`SptAkiProfileEditor::Editor`) to tie everything together.
6.  **Test**: Create scripts to test loading, modifying, and saving profiles.

By following this strategy, you can create a powerful command-line tool for editing SPT-AKI profiles in Ruby.
