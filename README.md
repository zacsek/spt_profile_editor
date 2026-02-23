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

### Interactive TUI Editor

The fastest way to edit your profile is using the built-in TUI editor. It provides a visual interface for managing your character's skills and inventory.

```bash
spt-editor
```

#### TUI Features

- **Profile Selector**: Easily browse and select from all available SPT profiles.
- **Skill Management**: View and modify common skills with immediate feedback.
- **Inventory Management**:
    - **Live Filtering**: Press `\` to search through your current inventory.
    - **Smart Sorting**: Press `o` to toggle between name and count-based sorting.
    - **Item Addition**: Press `/` to search the entire SPT item database and add items directly to your stash with custom quantities.
- **Dynamic Layout**: Modern interface with overlay modals and responsive pane management.

#### Keyboard Shortcuts

| Key | Action |
| :--- | :--- |
| `Tab` | Toggle focus between Skills and Inventory panes |
| `\` | Open local inventory search/filter |
| `/` | Open global item database search (Add Item) |
| `o` | Toggle inventory sort mode (None → Name → Count) |
| `+` / `-` | Increase/Decrease selected skill progress |
| `Home` / `End` | Jump to start/end of lists |
| `PgUp` / `PgDn` | Scroll lists by 10 items |
| `Ctrl+S` | Save all changes to the profile |
| `q` | Quit application (works globally unless typing) |
| `Esc` | Unfocus pane, close modal, or go back |

### Interactive Console

For power users, a Ruby-based REPL is available.

```bash
spt-console
```

This launches a console where you can list profiles, load them, search for items, and edit the inventory using helper commands like `search_item`, `add_item`, and `save`.

### Library Usage (Ruby API)

You can also use the gem programmatically in your own scripts.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.
