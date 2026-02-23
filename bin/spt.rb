require 'rooibos'
require "irb"

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'spt_profile_editor'
require 'fileutils'

ENV['SPT_PATH'] = '/home/zacsek/Games/tarkov/drive_c/SPTarkov/SPT'

# Check environment
unless ENV['SPT_PATH']
  puts "Error: SPT_PATH environment variable is not set."
  puts "Please set it to the root of your SPT-AKI server installation."
  exit 1
end

# -------------------------------------------

module App
  Model = Data.define(:screen, :selector_model, :editor_model)

  Init = -> {
    selector_model = Selector.init
    Model.new(screen: :selector, selector_model: selector_model, editor_model: nil)
  }

  View = -> (model, tui) {
    case model.screen
    when :selector
      Selector.view(model.selector_model, tui)
    when :editor
      Editor.view(model.editor_model, tui)
    end
  }

  Update = -> (msg, model) {
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
  Model = Data.define(:profiles, :selected)
  ProfileItem = Data.define(:id, :info, :profile)

  def self.init
    profiles = list_profiles
    Model.new(profiles: profiles, selected: profiles.first)
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
        titles: ["Select profile", { content: KEYS, position: :bottom, alignment: :right}],
        borders: [:all],
        border_type: :rounded,
        border_style: tui.style(fg: :green),
        children: [
          tui.list(items: model.profiles.map(&:info),
                   selected_index: model.profiles.index(model.selected),
                   highlight_symbol: ">",
                   highlight_style: tui.style(modifiers: [:reversed])
                  )
        ]
      )
    )
  end

  def self.update(msg, model)
    if msg.ctrl_c? || msg.q? then Rooibos::Command.exit
    elsif msg.up_arrow? then select_index(model, -1)
    elsif msg.down_arrow? then select_index(model, 1)
    elsif msg.enter? then Editor.init(model.selected.profile)
    else model
    end
  end

  private

  KEYS = "↑/↓/Home/End: Select | Enter: Open | q: Quit"

  def self.select_index(model, delta)
    new_index = (model.profiles.index(model.selected) + delta).clamp(0, model.profiles.length - 1)
    model.with(selected: model.profiles[new_index])
  end

  def self.list_profiles
    profiles_dir = File.join(SptProfileEditor.configuration.server_path, 'user', 'profiles')
    files = Dir.glob(File.join(profiles_dir, '*.json'))
    
    if files.empty?
      puts "No profiles found in #{profiles_dir}"
      exit 1
    end

    editor = SptProfileEditor::Editor.new

    files.map do |f|
      id = File.basename(f, '.json')
      profile = editor.load_profile(id)
      pmc = profile.pmc.info
      info = " #{"%24s" % id}  -  #{pmc['Nickname']} | #{pmc['Side'].upcase} | Lvl #{pmc['Level']}"

      ProfileItem.new(id:, info:, profile:)
    end
  end
end

module Editor
  Model = Data.define(:profile, :focus, :selected_skill_index, :selected_inventory_index, :search_query)

  def self.init(profile)
    Model.new(profile: profile, focus: :inventory, selected_skill_index: 0, selected_inventory_index: 0, search_query: "")
  end

  def self.view(model, tui)
    pmc = model.profile.pmc
    common_skills = pmc.skills['Common']
    skills_list = common_skills.map { |s| "#{s['Id']}: #{(s['Progress'] / 100.0).round(2)} Lvl" }
    
    # Filter inventory
    items = pmc.inventory.all_items
    unless model.search_query.empty?
      items = items.select { |i| i.name.downcase.include?(model.search_query.downcase) }
    end
    
    inventory_items = items.map { |i| "#{i.name} (x#{i.count})" }
    
    # TPL ID for hovered item
    hovered_item = items[model.selected_inventory_index]
    tpl_info = hovered_item ? " [TPL: #{hovered_item.tpl}]" : ""

    keys_help = "i: Inventory | s: Skills | \\: Search | Esc: Back"
    if model.focus == :skills
      keys_help = "↑/↓: Nav | +/-: Level | Esc: Back"
    elsif model.focus == :inventory
      keys_help = "↑/↓: Nav | Esc: Back"
    elsif model.focus == :search
      keys_help = "Enter: Finish | Esc: Cancel"
    end

    tui.layout(
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
              title: "Inventory#{tpl_info} (#{keys_help})",
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
        (tui.block(
          title: "Search (Case-insensitive)",
          borders: [:all],
          border_style: model.focus == :search ? tui.style(fg: :cyan) : tui.style,
          children: [
            tui.paragraph(text: model.search_query)
          ]
        ) if model.focus == :search || !model.search_query.empty?)
      ].compact
    )
  end

  def self.update(msg, model)
    if msg.ctrl_c? || msg.q? then Rooibos::Command.exit
    elsif model.focus == :skills
      update_skills(msg, model)
    elsif model.focus == :inventory
      update_inventory(msg, model)
    elsif model.focus == :search
      update_search(msg, model)
    else
      # Idle/General focus
      if msg.esc? then :back
      elsif msg.s? then model.with(focus: :skills)
      elsif msg.i? then model.with(focus: :inventory)
      elsif msg.backslash? then model.with(focus: :search)
      else model
      end
    end
  end

  private

  def self.update_inventory(msg, model)
    pmc = model.profile.pmc
    items = pmc.inventory.all_items
    unless model.search_query.empty?
      items = items.select { |i| i.name.downcase.include?(model.search_query.downcase) }
    end

    if msg.esc?
      model.with(focus: :none)
    elsif msg.up_arrow? || msg.k?
      new_idx = (model.selected_inventory_index - 1).clamp(0, [0, items.length - 1].max)
      model.with(selected_inventory_index: new_idx)
    elsif msg.down_arrow? || msg.j?
      new_idx = (model.selected_inventory_index + 1).clamp(0, [0, items.length - 1].max)
      model.with(selected_inventory_index: new_idx)
    elsif msg.s?
      model.with(focus: :skills)
    elsif msg.backslash?
      model.with(focus: :search)
    else
      model
    end
  end

  def self.update_skills(msg, model)
    pmc = model.profile.pmc
    skills = pmc.skills['Common']

    if msg.esc?
      model.with(focus: :none)
    elsif msg.up_arrow? || msg.k?
      new_idx = (model.selected_skill_index - 1).clamp(0, skills.length - 1)
      model.with(selected_skill_index: new_idx)
    elsif msg.down_arrow? || msg.j?
      new_idx = (model.selected_skill_index + 1).clamp(0, skills.length - 1)
      model.with(selected_skill_index: new_idx)
    elsif msg.plus? || msg.equals?
      skills[model.selected_skill_index]['Progress'] += 100
      model
    elsif msg.minus?
      skills[model.selected_skill_index]['Progress'] = [0, skills[model.selected_skill_index]['Progress'] - 100].max
      model
    elsif msg.i?
      model.with(focus: :inventory)
    elsif msg.backslash?
      model.with(focus: :search)
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
end

Rooibos.run(App)
