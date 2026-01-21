# Porting SPT-AKI Profile Editor to Ruby

This document outlines the strategy and progress for porting the core, non-UI functionality of the C# SPT-AKI Profile Editor to a Ruby gem. The goal is to create a library that can programmatically read, modify, and save SPT-AKI profile files.

## 1. Project Analysis

The C# project is a WPF application that uses the MVVM pattern. The core logic is well-separated from the UI.

- **Data Format**: The profile files are **JSON**.
- **Core Dependency**: The project heavily relies on `Newtonsoft.Json` for all JSON operations. The Ruby equivalent is the built-in `json` gem.
- **Saving Mechanism**: The editor does **not** simply overwrite the profile with its in-memory representation. It reads the original JSON file into a mutable `JObject`, surgically modifies specific sections of this object, and then writes the modified `JObject` back to a file. This is done to preserve any data in the profile that the editor doesn't explicitly handle. **This is a critical detail to replicate.**
- **Data Models**: The core data structures are defined in `SPT-AKI Profile Editor/Core/ProfileClasses/`. The key classes are:
    - `Profile.cs`: The root object of the profile file.
    - `Character.cs`: Represents a PMC or Scav character, containing the bulk of the editable data (info, health, skills, quests, inventory, etc.). This class also contains many of the high-level editing methods (e.g., `SetAllTradersMax`).
    - `ProfileSaver.cs`: Contains the logic for the complex save mechanism described above.
- **External Game Data**: The editor's logic depends on external game data loaded from the SPT-AKI server installation (e.g., item definitions, quest trees, trader data). This data is loaded into a global `AppData.ServerDatabase` object and is referenced throughout the code. The Ruby gem uses a `ServerDatabase` class to access this data.

## 2. Implementation Progress

### Completed Features

-   [x] **Gem Scaffolding**: Created `spt_profile_editor` gem structure.
-   [x] **Configuration**: Implemented `SPT_PATH` environment variable support.
-   [x] **Server Database**: Implemented `ServerDatabase` to load items, locales, and other game data from the SPT-AKI server path.
-   [x] **Data Models**: Ported `Profile`, `CharacterSet`, and `Character` classes.
-   [x] **Loading Logic**: Implemented `ProfileLoader` to parse profile JSON.
-   [x] **Saving Logic**: Implemented basic `ProfileSaver` (currently uses a merge strategy; full surgical update per C# spec is in progress).
-   [x] **Item Search**: Added `search_items_by_name` to `ServerDatabase` and exposed it via the `Editor`.
-   [x] **Inventory Management**:
    -   Implemented `Inventory` and `InventoryItem` classes.
    -   Added `add_item_by_id` logic to handle adding items (stackable and non-stackable) to the stash.
    -   Added convenience `add_money` method.
-   [x] **Interactive Console**: Created `bin/spt-console`, an IRB-based REPL for interactive profile management.

### Pending Features

-   [ ] **Full "Surgical" Save**: Refine `ProfileSaver` to strictly match the C# project's read-modify-write logic for all sections (Quests, Skills, etc.) to ensure 100% safety for unmapped data.
-   [ ] **Quest Editing**: Port logic for modifying quest status.
-   [ ] **Trader Editing**: Port logic for editing trader standing and loyalty levels.
-   [ ] **Skill Editing**: Port logic for modifying character skills (Common and Mastering).
-   [ ] **Hideout Management**: Port logic for Hideout areas and production.

## 3. Ruby Gem Structure

### Core Components

1.  **`Configuration`**: Handles `SPT_PATH`.
2.  **`ServerDatabase`**: Loads global game data (Items, Locales, etc.).
3.  **`Profile` / `Character`**: Represents the player state.
4.  **`Inventory`**: Manages the item grid (simplified) and stash.
5.  **`Editor`**: The main entry point facade.

### Interactive Console (`spt-console`)

A CLI tool has been added to `bin/spt-console`. It provides an interactive Ruby shell with pre-loaded context:

*   **`load_profile(name)`**: Loads a user profile.
*   **`search_item(name)`**: Finds items in the database by name (e.g., "Graphics Card").
*   **`add_item(id, count)`**: Adds items to the player's stash.
*   **`save`**: Saves the profile with an automatic timestamped backup.
*   **`pmc` / `scav`**: Direct access to character objects.

## 4. Usage Examples

### Scripting

```ruby
require 'spt_profile_editor'

editor = SptProfileEditor::Editor.new
editor.load_profile('my_profile')

# Modify level
editor.profile.pmc.level = 42

# Add money
editor.profile.pmc.inventory.add_money('5449016a4bdc2d6f028b456f', 1000000)

# Save
editor.save_profile
```

### Console

```bash
$ spt-console
SPT Profile Editor Console
Type 'help' for available commands.

irb(main):001:0> load_profile 'aid82...'
Profile loaded.
=> nil

irb(main):002:0> search_item 'bitcoin'
Found 1 items:
59faff1d86f7746c51718c9c   | Physical Bitcoin
=> nil

irb(main):003:0> add_item '59faff1d86f7746c51718c9c', 5
Warning: Added item 59faff1d86f7746c51718c9c (count: 5) at placeholder location.
Added 5 of 59faff1d86f7746c51718c9c.
=> nil

irb(main):004:0> save
Backup created at: .../user/profiles/aid82....json.20231027_120000.bak
Profile saved to .../user/profiles/aid82....json
=> nil
```