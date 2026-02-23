# SPT Data Structures

A detailed guide to the Single-Player Tarkov (SPT) profile JSON and database structures.

## Profile Schema (`user/profiles/*.json`)

### Root Object
- `id`: Unique profile identifier (e.g., `65d64817...`)
- `characters`: Contains `pmc` and `scav` sub-objects.
- `userbuilds`: User-defined weapon builds.
- `customisationUnlocks`: Array of unlocked clothing.

### Character Object (`pmc`/`scav`)
- `Info`: Nickname, Side (USEC/BEAR), Level, Experience, MemberCategory.
- `Health`: Current/Max HP for each body part (Head, Chest, Stomach, etc.).
- `Skills`: Physical, Mental, Combat, Special skills.
- `Inventory`: The character's items and equipment.
- `Quests`: Array of quest statuses.

### Inventory Object
- `items`: Flattened list of all items (equipment, backpack, stash, containers).
- `equipment`: The `_id` of the top-level equipment item.
- `stash`: The `_id` of the stash item.
- `questRaidItems`: The `_id` of the quest items stash.
- `sortingTable`: The `_id` of the sorting table.

## Item Object (`items` array)
- `_id`: Unique instance ID (GUID).
- `_tpl`: The template ID (references `templates/items.json`).
- `parentId`: The ID of the container holding this item.
- `slotId`: The slot name (e.g., `main`, `SecuredContainer`, `TacticalVest`).
- `location`: For items in a grid (x, y, rotation).
- `upd`: Object containing variable data (StackCount, Durability, MedKit usage, etc.).

## Server Database (`Aki_Data/Server/database/`)
- `templates/items.json`: Maps `_tpl` IDs to item properties (Name, Size, Weight, etc.).
- `locales/global/en.json`: Human-readable names, descriptions, and UI text.
- `globals.json`: Server-wide settings (Experience curves, health regeneration).
