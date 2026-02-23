---
name: spt-editor-dev
description: Development and maintenance of the SPT Profile Editor (Ruby). Use when working on the Ruby codebase, implementing SPT profile (JSON) logic, or developing the TUI using Rooibos/ratatui-ruby.
---

# SPT Profile Editor Development

This skill guides development for the SPT Profile Editor, a Ruby-based tool for editing Single-Player Tarkov (SPT) savegames.

## Core Architecture

- **`bin/spt.rb`**: The main TUI entry point.
- **`lib/spt_profile_editor/`**: Core logic and domain models.
  - `Profile`: Root object containing PMC and Scav data.
  - `Character`: Represents PMC/Scav (Info, Health, Skills, Inventory).
  - `Inventory`: Handles the complex item grid and equipment.
  - `ServerDatabase`: Loads SPT server templates (items, locales) for lookups.
- **`spec/`**: RSpec test suite.

## TUI Development (Rooibos)

The TUI follows an **Elm-like architecture** (Model-View-Update).

### 1. Model
Define a `Data.define` or class to hold the screen state.
```ruby
Model = Data.define(:profile, :selected_tab)
```

### 2. View
A lambda that returns `ratatui` widgets. Use `tui.block`, `tui.list`, `tui.paragraph`, etc.
```ruby
View = -> (model, tui) {
  tui.block(title: "Editor", borders: [:all], children: [...])
}
```

### 3. Update
A lambda that handles messages (keys, events) and returns a *new* model.
```ruby
Update = -> (msg, model) {
  if msg.q? then Rooibos::Command.exit
  else model
  end
}
```

## Working with SPT Profiles

- **Profile Structure**: See [spt_data_structures.md](references/spt_data_structures.md) for a detailed breakdown of the JSON schema.
- **Item Lookups**: Use `ServerDatabase` to find item names/properties by their `_tpl` ID.
- **Saving**: Always use `ProfileSaver` to ensure changes are serialized back to the profile JSON correctly.

## Testing Guidelines

- **RSpec**: All logic changes must be covered by tests in `spec/`.
- **Fixtures**: Use `spec/fixtures/profile.json` for integration tests.
- **Command**: Run `bundle exec rspec` to verify changes.

## Best Practices

- **Surgical Updates**: When modifying the TUI, keep the `View` functions clean and delegate complex layout logic to helper methods.
- **Type Safety**: Use `Data.define` for simple value objects.
- **Error Handling**: Validate the `SPT_PATH` and profile existence before operations.
