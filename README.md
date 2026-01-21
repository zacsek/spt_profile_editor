# SPT Profile Editor (Ruby)

A Ruby library for reading and programmatically editing SPT-AKI player profiles. This gem is a partial port of the functionality from the C# [SPT-AKI Profile Editor](https://github.com/SkiTles55/SPT-AKI-Profile-Editor).

## Installation

This gem is not yet published to RubyGems. To use it, clone the repository and build it locally.

1.  Build the gem from the source:
    ```bash
    gem build spt_profile_editor.gemspec
    ```

2.  Install the locally built gem:
    ```bash
    gem install ./spt_profile_editor-x.y.z.gem
    ```
    (Replace `x.y.z` with the current version number).

## Configuration

Before using the gem, you must set the `SPT_PATH` environment variable to the root directory of your SPT-AKI server installation.

```bash
export SPT_PATH="/path/to/your/spt-aki/server"
```

The gem uses this path to find both your user profiles and the necessary server database files (e.g., item definitions, locales).

## Usage

### Loading a Profile

First, create an `Editor` instance. Then, use the `load_profile` method with the name of your profile file (without the `.json` extension). Profile files are typically found in `<SPT_PATH>/user/profiles/` and have a `.json` extension.

```ruby
require 'spt_profile_editor'

# The editor will automatically pick up the SPT_PATH environment variable.
editor = SptProfileEditor::Editor.new

# Load the profile associated with 'your_profile_id.json'
editor.load_profile('your_profile_id')

# Access the loaded profile object
profile = editor.profile
```

### Editing Character Data

You can access character data through the `profile` object. The PMC character is available via `profile.pmc`.

```ruby
# Get the PMC character object
pmc = profile.pmc

# Read character level and nickname
puts "Nickname: #{pmc.nickname}"
puts "Current Level: #{pmc.level}"

# Change the character's level
pmc.level = 50
puts "New Level: #{pmc.level}"
```

### Inventory Management

You can access a character's inventory through the `inventory` attribute.

**Listing Money**

The `inventory.money` method returns an array of all money items in the stash.

```ruby
puts "Money in Stash:"
pmc.inventory.money.each do |money_stack|
  puts "- #{money_stack.name}: #{money_stack.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
end
```

**Adding Money**

Use the `add_money` method to add a specific amount of a currency. You need the item's template ID (`_tpl`).

-   **Roubles:** `5449016a4bdc2d6f028b456f`
-   **Dollars:** `5696686a4bdc2da3298b456a`
-   **Euros:** `569668774bdc2da2298b4568`

```ruby
# Add 500,000 Roubles
roubles_tpl = "5449016a4bdc2d6f028b456f"
pmc.inventory.add_money(roubles_tpl, 500_000)

puts "Added 500,000 Roubles."
```
> **Note:** The `add_money` function is currently simplified. If a stack of the specified currency already exists, it will be added to it. If not, a new item will be created at a placeholder location in the stash, which may not correspond to a valid free slot. Full grid-based slot finding is not yet implemented.

### Saving the Profile

After making changes, you can save the profile back to the original file or to a new file.

```ruby
# Save changes back to the original profile file
editor.save_profile

# Or, save to a new file
# editor.save_profile("/path/to/new_profile.json")

puts "Profile saved successfully."
```

### Interactive Console

The gem comes with an interactive console for easier profile management.

```bash
spt-console
```

This launches a REPL where you can list profiles, load them, search for items, and edit the inventory using helper commands like `search_item`, `add_item`, and `save`.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.
