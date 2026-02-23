require "rooibos"
require "irb"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "spt_profile_editor"
require "fileutils"

ENV["SPT_PATH"] = "/home/zacsek/Games/tarkov/drive_c/SPTarkov/SPT"

# Check environment
unless ENV["SPT_PATH"]
  puts "Error: SPT_PATH environment variable is not set."
  puts "Please set it to the root of your SPT-AKI server installation."
  exit 1
end

# -------------------------------------------

module App
  Model = Data.define(:screen, :selector_model, :editor_model, :editor)

  Init = lambda {
    editor = SptProfileEditor::Editor.new
    selector_model = Selector.init(editor)
    Model.new(screen: :selector, selector_model: selector_model, editor_model: nil, editor: editor)
  }

  View = lambda { |model, tui|
    case model.screen
    when :selector
      Selector.view(model.selector_model, tui)
    when :editor
      Editor.view(model.editor_model, tui)
    end
  }

  Update = lambda { |msg, model|
    case model.screen
    when :selector
      res = Selector.update(msg, model.selector_model)
      case res
      when Editor::Model
        model.with(screen: :editor, editor_model: res)
      when Rooibos::Command::Custom
        [model, res]
      else
        model.with(selector_model: res)
      end
    when :editor
      res = Editor.update(msg, model.editor_model)
      case res
      when :back
        model.with(screen: :selector)
      when Rooibos::Command::Custom
        [model, res]
      else
        model.with(editor_model: res)
      end
    end
  }
end

module Selector
  Model = Data.define(:profiles, :selected, :editor)
  ProfileItem = Data.define(:id, :info, :profile)

  def self.init(editor)
    profiles = list_profiles(editor)
    Model.new(profiles: profiles, selected: profiles.first, editor: editor)
  end

  def self.view(model, tui)
    max_width = model.profiles.map { |p| tui.text_width(p.info) }.max || 0
    keys_width = tui.text_width(KEYS)
    title_width = tui.text_width("Select profile")

    width = [max_width, keys_width, title_width].max + 8
    height = model.profiles.length + 2

    vp = tui.viewport_area
    w_pct = (width.to_f / vp.width * 100).ceil.clamp(1, 100)
    h_pct = (height.to_f / vp.height * 100).ceil.clamp(1, 100)

    tui.center(
      width_percent: w_pct,
      height_percent: h_pct,
      child: tui.block(
        titles: ["Select profile", { content: KEYS, position: :bottom, alignment: :right }],
        borders: [:all],
        border_type: :rounded,
        border_style: tui.style(fg: :green),
        children: [
          tui.list(items: model.profiles.map(&:info),
                   selected_index: model.profiles.index(model.selected),
                   highlight_symbol: ">",
                   highlight_style: tui.style(modifiers: [:reversed]))
        ]
      )
    )
  end

  def self.update(msg, model)
    if msg.ctrl_c? || msg.q? then Rooibos::Command.exit
    elsif msg.up_arrow? then select_index(model, -1)
    elsif msg.down_arrow? then select_index(model, 1)
    elsif msg.enter? then Editor.init(model.selected.profile, model.editor, model.selected.id)
    else model
    end
  end

  KEYS = "↑/↓/Home/End: Select | Enter: Open | q: Quit"

  def self.select_index(model, delta)
    new_index = (model.profiles.index(model.selected) + delta).clamp(0, model.profiles.length - 1)
    model.with(selected: model.profiles[new_index])
  end

  def self.list_profiles(editor)
    profiles_dir = File.join(SptProfileEditor.configuration.server_path, "user", "profiles")
    files = Dir.glob(File.join(profiles_dir, "*.json"))

    if files.empty?
      puts "No profiles found in #{profiles_dir}"
      exit 1
    end

    files.map do |f|
      id = File.basename(f, ".json")
      profile = editor.load_profile(id)
      pmc = profile.pmc.info
      info = " #{"%24s" % id}  -  #{pmc["Nickname"]} | #{pmc["Side"].upcase} | Lvl #{pmc["Level"]}"

      ProfileItem.new(id:, info:, profile:)
    end
  end
end

module Editor
  Model = Data.define(:profile, :focus, :selected_skill_index, :selected_inventory_index, :search_query,
                      :item_search_query, :item_search_results, :selected_item_search_index, :quantity_input, :editor, :sort_order, :save_message)

  def self.init(profile, editor, profile_id)
    editor.profile = profile
    editor.profile_path = File.join(SptProfileEditor.configuration.server_path, "user", "profiles", "#{profile_id}.json")
    Model.new(profile: profile, focus: :inventory, selected_skill_index: 0, selected_inventory_index: 0, search_query: "",
              item_search_query: "", item_search_results: [], selected_item_search_index: 0, quantity_input: "1", editor: editor, sort_order: :none, save_message: nil)
  end

  def self.view(model, tui)
    pmc = model.profile.pmc
    common_skills = pmc.skills["Common"]
    skills_list = common_skills.map { |s| "#{s["Id"]}: #{(s["Progress"] / 100.0).round(2)} Lvl" }

    # Filter inventory
    items = pmc.inventory.all_items
    items = items.select { |i| i.name.downcase.include?(model.search_query.downcase) } unless model.search_query.empty?

    case model.sort_order
    when :name
      items = items.sort_by { |i| i.name.downcase }
    when :count
      items = items.sort_by(&:count).reverse
    end

    inventory_items = items.map { |i| "#{i.name} (x#{i.count})" }

    # TPL ID for hovered item
    hovered_item = items[model.selected_inventory_index]
    tpl_info = hovered_item ? " [TPL: #{hovered_item.tpl}]" : ""
    sort_info = model.sort_order == :none ? "" : " [Sorted by #{model.sort_order}]"
    save_info = model.save_message ? " [#{model.save_message}]" : ""
    keys_help = "i: Inventory | s: Skills | Tab: Toggle | \\: Search | /: Add Item | Ctrl+S: Save | Esc: Back"
    if model.focus == :skills
      keys_help = "↑/↓: Nav | +/-: Level | Esc: Back"
    elsif model.focus == :inventory
      keys_help = "↑/↓: Nav | o: Sort | Esc: Back"
    elsif model.focus == :search
      keys_help = "Enter: Finish | Esc: Cancel"
    elsif model.focus == :item_search
      keys_help = "Enter: Select | Esc: Cancel"
    elsif model.focus == :quantity_input
      keys_help = "Enter: Add | Esc: Cancel"
    end

    main_view = tui.layout(
      direction: :vertical,
      constraints: [
        tui.constraint_min(0),
        tui.constraint_length(3) # Search bar height if visible
      ],
      children: [
        tui.layout(
          direction: :horizontal,
          constraints: [
            tui.constraint_percentage(30),
            tui.constraint_percentage(70)
          ],
          children: [
            tui.block(
              title: "Skills",
              borders: [:all],
              border_style: model.focus == :skills ? tui.style(fg: :yellow) : tui.style,
              children: [
                tui.list(
                  items: skills_list,
                  selected_index: model.focus == :skills ? model.selected_skill_index : nil,
                  highlight_symbol: ">",
                  highlight_style: tui.style(modifiers: [:reversed])
                )
              ]
            ),
            tui.block(
              title: "Inventory#{tpl_info}#{sort_info}#{save_info} (#{keys_help})",
              borders: [:all],
              border_style: model.focus == :inventory ? tui.style(fg: :yellow) : tui.style,
              children: [
                tui.list(
                  items: inventory_items,
                  selected_index: model.focus == :inventory ? model.selected_inventory_index : nil,
                  highlight_symbol: ">",
                  highlight_style: tui.style(modifiers: [:reversed])
                )
              ]
            )
          ]
        ),
        (if model.focus == :search || !model.search_query.empty?
           tui.block(
             title: "Search (Case-insensitive)",
             borders: [:all],
             border_style: model.focus == :search ? tui.style(fg: :cyan) : tui.style,
             children: [
               tui.paragraph(text: model.search_query)
             ]
           )
         end)
      ].compact
    )

    if model.focus == :item_search
      vp = tui.viewport_area
      results_count = model.item_search_results.length
      results_height = [results_count, 1].max + 2 # +2 for borders
      total_height_rows = results_height + 3 + 2 # +3 for query box, +2 for outer block borders
      total_height_pct = (total_height_rows.to_f / vp.height * 100).clamp(20, 80)

      tui.overlay(
        layers: [
          main_view,
          tui.center(
            width_percent: 80,
            height_percent: total_height_pct,
            child: tui.block(
              title: "Add Item",
              borders: [:all],
              border_style: tui.style(fg: :cyan),
              children: [
                tui.clear,
                tui.layout(
                  direction: :vertical,
                  constraints: [
                    tui.constraint_length(3),
                    tui.constraint_min(0)
                  ],
                  children: [
                    tui.block(title: "Query", borders: [:all], children: [tui.paragraph(text: model.item_search_query)]),
                    tui.block(title: "Results", borders: [:all], children: [
                      tui.list(
                        items: model.item_search_results.map { |r| r[:name] },
                        selected_index: model.selected_item_search_index,
                        highlight_symbol: ">",
                        highlight_style: tui.style(modifiers: [:reversed])
                      )
                    ])
                  ]
                )
              ]
            )
          )
        ]
      )
    elsif model.focus == :quantity_input
      selected_item = model.item_search_results[model.selected_item_search_index]
      vp = tui.viewport_area
      # 3 rows for item name paragraph, 3 rows for quantity input box, +2 for outer borders
      total_height_rows = 3 + 3 + 2
      total_height_pct = (total_height_rows.to_f / vp.height * 100).clamp(10, 40)

      tui.overlay(
        layers: [
          main_view,
          tui.center(
            width_percent: 50,
            height_percent: total_height_pct,
            child: tui.block(
              title: "Add Item - Quantity",
              borders: [:all],
              border_style: tui.style(fg: :cyan),
              children: [
                tui.clear,
                tui.layout(
                  direction: :vertical,
                  constraints: [
                    tui.constraint_length(3),
                    tui.constraint_length(3)
                  ],
                  children: [
                    tui.paragraph(text: "Item: #{selected_item[:name]}"),
                    tui.block(title: "Quantity", borders: [:all], children: [
                      tui.paragraph(text: model.quantity_input)
                    ])
                  ]
                )
              ]
            )
          )
        ]
      )
    else
      main_view
    end
  end

  def self.update(msg, model)
    if msg.ctrl_c? then Rooibos::Command.exit
    elsif msg.ctrl_s?
      model.editor.save_profile
      return model.with(save_message: "Profile Saved!")
    end

    model = model.with(save_message: nil) if model.save_message

    if model.focus == :item_search
      update_item_search(msg, model)
    elsif model.focus == :quantity_input
      update_quantity_input(msg, model)
    elsif model.focus == :search
      update_search(msg, model)
    elsif msg.q?
      Rooibos::Command.exit
    elsif msg.slash?
      model.with(focus: :item_search)
    elsif msg.tab?
      new_focus = model.focus == :skills ? :inventory : :skills
      model.with(focus: new_focus)
    elsif msg.s?
      model.with(focus: :skills)
    elsif msg.i?
      model.with(focus: :inventory)
    elsif msg.backslash?
      model.with(focus: :search)
    elsif model.focus == :skills
      update_skills(msg, model)
    elsif model.focus == :inventory
      update_inventory(msg, model)
    elsif msg.esc?
      model.focus == :inventory || model.focus == :skills ? model.with(focus: :none) : :back
    else
      model
    end
  end

  def self.update_inventory(msg, model)
    pmc = model.profile.pmc
    items = pmc.inventory.all_items
    items = items.select { |i| i.name.downcase.include?(model.search_query.downcase) } unless model.search_query.empty?

    case model.sort_order
    when :name
      items = items.sort_by { |i| i.name.downcase }
    when :count
      items = items.sort_by(&:count).reverse
    end

    if msg.esc?
      model.with(focus: :none)
    elsif msg.up_arrow? || msg.k?
      new_idx = (model.selected_inventory_index - 1).clamp(0, [0, items.length - 1].max)
      model.with(selected_inventory_index: new_idx)
    elsif msg.down_arrow? || msg.j?
      new_idx = (model.selected_inventory_index + 1).clamp(0, [0, items.length - 1].max)
      model.with(selected_inventory_index: new_idx)
    elsif msg.home?
      model.with(selected_inventory_index: 0)
    elsif msg.end?
      model.with(selected_inventory_index: [0, items.length - 1].max)
    elsif msg.page_up?
      new_idx = (model.selected_inventory_index - 10).clamp(0, [0, items.length - 1].max)
      model.with(selected_inventory_index: new_idx)
    elsif msg.page_down?
      new_idx = (model.selected_inventory_index + 10).clamp(0, [0, items.length - 1].max)
      model.with(selected_inventory_index: new_idx)
    elsif msg.o?
      new_sort = case model.sort_order
                 when :none then :name
                 when :name then :count
                 else :none
                 end
      model.with(sort_order: new_sort, selected_inventory_index: 0)
    else
      model
    end
  end

  def self.update_skills(msg, model)
    pmc = model.profile.pmc
    skills = pmc.skills["Common"]

    if msg.esc?
      model.with(focus: :none)
    elsif msg.up_arrow? || msg.k?
      new_idx = (model.selected_skill_index - 1).clamp(0, skills.length - 1)
      model.with(selected_skill_index: new_idx)
    elsif msg.down_arrow? || msg.j?
      new_idx = (model.selected_skill_index + 1).clamp(0, skills.length - 1)
      model.with(selected_skill_index: new_idx)
    elsif msg.home?
      model.with(selected_skill_index: 0)
    elsif msg.end?
      model.with(selected_skill_index: [0, skills.length - 1].max)
    elsif msg.page_up?
      new_idx = (model.selected_skill_index - 10).clamp(0, skills.length - 1)
      model.with(selected_skill_index: new_idx)
    elsif msg.page_down?
      new_idx = (model.selected_skill_index + 10).clamp(0, skills.length - 1)
      model.with(selected_skill_index: new_idx)
    elsif msg.plus? || msg.equals?
      skills[model.selected_skill_index]["Progress"] += 100
      model
    elsif msg.minus?
      skills[model.selected_skill_index]["Progress"] = [0, skills[model.selected_skill_index]["Progress"] - 100].max
      model
    else
      model
    end
  end

  def self.update_search(msg, model)
    if msg.enter?
      model.with(focus: :inventory)
    elsif msg.esc?
      model.with(focus: :inventory, search_query: "")
    elsif msg.backspace?
      model.with(search_query: model.search_query[0...-1])
    elsif msg.char
      model.with(search_query: model.search_query + msg.char)
    else
      model
    end
  end

  def self.update_item_search(msg, model)
    if msg.enter?
      if model.item_search_results.empty?
        model
      else
        model.with(focus: :quantity_input, quantity_input: "1")
      end
    elsif msg.esc?
      model.with(focus: :inventory, item_search_query: "", item_search_results: [], selected_item_search_index: 0)
    elsif msg.up_arrow? || msg.k?
      new_idx = (model.selected_item_search_index - 1).clamp(0, [0, model.item_search_results.length - 1].max)
      model.with(selected_item_search_index: new_idx)
    elsif msg.down_arrow? || msg.j?
      new_idx = (model.selected_item_search_index + 1).clamp(0, [0, model.item_search_results.length - 1].max)
      model.with(selected_item_search_index: new_idx)
    elsif msg.home?
      model.with(selected_item_search_index: 0)
    elsif msg.end?
      model.with(selected_item_search_index: [0, model.item_search_results.length - 1].max)
    elsif msg.page_up?
      new_idx = (model.selected_item_search_index - 10).clamp(0, [0, model.item_search_results.length - 1].max)
      model.with(selected_item_search_index: new_idx)
    elsif msg.page_down?
      new_idx = (model.selected_item_search_index + 10).clamp(0, [0, model.item_search_results.length - 1].max)
      model.with(selected_item_search_index: new_idx)
    elsif msg.backspace?
      new_query = model.item_search_query[0...-1]
      results = model.editor.search_item(new_query)
      model.with(item_search_query: new_query, item_search_results: results, selected_item_search_index: 0)
    elsif msg.char
      new_query = model.item_search_query + msg.char
      results = model.editor.search_item(new_query)
      model.with(item_search_query: new_query, item_search_results: results, selected_item_search_index: 0)
    else
      model
    end
  end

  def self.update_quantity_input(msg, model)
    if msg.enter?
      count = model.quantity_input.to_i
      if count.positive?
        item = model.item_search_results[model.selected_item_search_index]
        model.profile.pmc.inventory.add_item_by_id(item[:id], count)
        model.with(focus: :inventory, item_search_query: "", item_search_results: [], selected_item_search_index: 0)
      else
        model
      end
    elsif msg.esc?
      model.with(focus: :item_search)
    elsif msg.backspace?
      model.with(quantity_input: model.quantity_input[0...-1])
    elsif msg.char && msg.char.match?(/\d/)
      model.with(quantity_input: model.quantity_input + msg.char)
    else
      model
    end
  end
end

Rooibos.run(App)
