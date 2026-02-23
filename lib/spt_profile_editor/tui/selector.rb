# frozen_string_literal: true

require "rooibos"

module SptProfileEditor
  module Tui
    module Selector
      Model = Data.define(:profiles, :selected, :editor)
      ProfileItem = Data.define(:id, :info, :profile)

      KEYS = "↑/↓/Home/End: Select | Enter: Open | q: Quit"

      def self.init(editor)
        profiles = list_profiles(editor)
        Model.new(profiles: profiles, selected: profiles.first, editor: editor)
      end

      def self.view(model, tui)
        max_width = model.profiles.map { |p| tui.text_width(p.info) }.max || 0
        width = [max_width, tui.text_width(KEYS), tui.text_width("Select profile")].max + 8
        height = model.profiles.length + 2

        vp = tui.viewport_area
        tui.center(
          width_percent: (width.to_f / vp.width * 100).ceil.clamp(1, 100),
          height_percent: (height.to_f / vp.height * 100).ceil.clamp(1, 100),
          child: tui.block(
            titles: ["Select profile", { content: KEYS, position: :bottom, alignment: :right }],
            borders: [:all],
            border_type: :rounded,
            border_style: tui.style(fg: :green),
            children: [
              tui.list(
                items: model.profiles.map(&:info),
                selected_index: model.profiles.index(model.selected),
                highlight_symbol: ">",
                highlight_style: tui.style(modifiers: [:reversed])
              )
            ]
          )
        )
      end

      def self.update(msg, model)
        return Rooibos::Command.exit if msg.q? || msg.ctrl_c?

        if msg.up_arrow? then select_index(model, -1)
        elsif msg.down_arrow? then select_index(model, 1)
        elsif msg.home? then model.with(selected: model.profiles.first)
        elsif msg.end? then model.with(selected: model.profiles.last)
        elsif msg.enter? then [:switch_to_editor, model.selected]
        else model
        end
      end

      def self.select_index(model, delta)
        new_index = (model.profiles.index(model.selected) + delta).clamp(0, model.profiles.length - 1)
        model.with(selected: model.profiles[new_index])
      end

      def self.list_profiles(editor)
        profiles_dir = File.join(SptProfileEditor.configuration.server_path, "user", "profiles")
        files = Dir.glob(File.join(profiles_dir, "*.json"))

        if files.empty?
          warn "No profiles found in #{profiles_dir}"
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
  end
end
