require 'rooibos'

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

module Selector
  Model = Data.define(:profiles, :selected)

  Init = -> {
    profiles = list_profiles
    Ractor.make_shareable(Model.new(profiles:, selected: profiles.first))
  }

  View = -> (model, tui) {
    tui.paragraph(
      titles: ["Select profile", { content: KEYS, position: bottom, alignment: :right}],
      borders: [:all],
      border_style: tui.style(fg: :green),
      children: [
        tui.list(items: model.profiles.map(&:info),
                 selected_index: model.profiles.index(model.selected),
                 highlight_symbol: ">",
                 highlight_style: tui.style(modifiers: [:reversed])
                )
      ]
    )
  }

  Update = -> (msg, model) {
    if msg.ctrl_c? || model.q? then Rooibos::Command.exit
    elsif msg.up_arrow? then Select[:-, model]
    elsif msg.down_arrow? then Select[:+, model]
    elsif msg.enter? then Open[model]
    end
  }

  private

  KEYS = "↑/↓/Home/End: Select | Enter: Open | q: Quit"

  Select = -> (operator, model) {
    new_index = model.profiles.index(model.selected).public_send(operator, 1)
    model.with(selected: model.profiles[new_index.clamp(0, model.profiles.length - 1)])
  }

  Open = -> (model) {
    Rooibos.run(Editor)
  }

  def list_profiles
    profiles_dir = File.join(SptProfileEditor.configuration.server_path, 'user', 'profiles')
    files = Dir.glob(File.join(profiles_dir, '*.json'))
    
    if files.empty?
      puts "No profiles found in #{profiles_dir}"
      return
    end

    files.map do |f|
      id = File.basename(f, '.json')
      profile = load_profile(profile_id)
      pmc = profile.pmc.info
      info = "#{basename}  >>  #{pmc['Nickname']} | #{pmc['Side'].upcase} | Lvl #{pmc['Level']}"

      {id:, info:, profile:}
    end
  end

  def load_profile(id)
    editor = SptProfileEditor::Editor.new
    editor.load_profile(name)
  end
end

module Editor
  Init = -> {}

  View = -> (model, tui) {
  }

  Update = -> (msg, model) {
  }
end

Rooibos.run(Selector)
