# frozen_string_literal: true

require "rooibos"

module SptProfileEditor
  module Tui
    module Editor
      Model = Data.define(
        :profile, :focus, :selected_skill_index, :selected_inventory_index,
        :search_query, :item_search_query, :item_search_results,
        :selected_item_search_index, :quantity_input, :editor,
        :sort_order, :save_message
      )

      def self.init(profile, editor, profile_id)
        editor.profile = profile
        editor.profile_path = File.join(SptProfileEditor.configuration.server_path, "user", "profiles", "#{profile_id}.json")
        Model.new(
          profile: profile, focus: :inventory, selected_skill_index: 0,
          selected_inventory_index: 0, search_query: "", item_search_query: "",
          item_search_results: [], selected_item_search_index: 0,
          quantity_input: "1", editor: editor, sort_order: :none, save_message: nil
        )
      end

      def self.view(model, tui)
        main_view = render_main_layout(model, tui)

        case model.focus
        when :item_search then render_item_search_modal(model, tui, main_view)
        when :quantity_input then render_quantity_modal(model, tui, main_view)
        else main_view
        end
      end

      def self.update(msg, model)
        return Rooibos::Command.exit if msg.ctrl_c?
        
        if msg.ctrl_s?
          model.editor.save_profile
          return model.with(save_message: "Profile Saved!")
        end

        # Clear save message on any other key
        model = model.with(save_message: nil) if model.save_message

        # Focused updates
        case model.focus
        when :item_search then return update_item_search(msg, model)
        when :quantity_input then return update_quantity_input(msg, model)
        when :search then return update_search(msg, model)
        end

        # Global keys
        if msg.q? then Rooibos::Command.exit
        elsif msg.slash? then model.with(focus: :item_search)
        elsif msg.tab? then model.with(focus: model.focus == :skills ? :inventory : :skills)
        elsif msg.s? then model.with(focus: :skills)
        elsif msg.i? then model.with(focus: :inventory)
        elsif msg.backslash? then model.with(focus: :search)
        elsif msg.esc? then model.focus == :none ? :back : model.with(focus: :none)
        elsif model.focus == :skills then update_skills(msg, model)
        elsif model.focus == :inventory then update_inventory(msg, model)
        else model
        end
      end

      # --- View Helpers ---

      def self.render_main_layout(model, tui)
        tui.layout(
          direction: :vertical,
          constraints: [tui.constraint_min(0), tui.constraint_length(model.focus == :search || !model.search_query.empty? ? 3 : 0)],
          children: [
            tui.layout(
              direction: :horizontal,
              constraints: [tui.constraint_percentage(30), tui.constraint_percentage(70)],
              children: [render_skills_pane(model, tui), render_inventory_pane(model, tui)]
            ),
            render_search_bar(model, tui)
          ].compact
        )
      end

      def self.render_skills_pane(model, tui)
        skills = model.profile.pmc.skills["Common"]
        list = skills.map { |s| "#{s["Id"]}: #{(s["Progress"] / 100.0).round(2)} Lvl" }
        tui.block(
          title: "Skills", borders: [:all],
          border_style: model.focus == :skills ? tui.style(fg: :yellow) : tui.style,
          children: [
            tui.list(
              items: list,
              selected_index: model.focus == :skills ? model.selected_skill_index : nil,
              highlight_symbol: ">", highlight_style: tui.style(modifiers: [:reversed])
            )
          ]
        )
      end

      def self.render_inventory_pane(model, tui)
        items = filtered_and_sorted_items(model)
        list = items.map { |i| "#{i.name} (x#{i.count})" }
        
        hovered = items[model.selected_inventory_index]
        tpl_info = hovered ? " [TPL: #{hovered.tpl}]" : ""
        sort_info = model.sort_order == :none ? "" : " [Sorted by #{model.sort_order}]"
        save_info = model.save_message ? " [#{model.save_message}]" : ""
        
        keys_help = "Tab: Toggle | \: Search | /: Add | Ctrl+S: Save | Esc: Back"
        keys_help = "↑/↓: Nav | o: Sort | Esc: Unfocus" if model.focus == :inventory

        tui.block(
          title: "Inventory#{tpl_info}#{sort_info}#{save_info} (#{keys_help})",
          borders: [:all], border_style: model.focus == :inventory ? tui.style(fg: :yellow) : tui.style,
          children: [
            tui.list(
              items: list,
              selected_index: model.focus == :inventory ? model.selected_inventory_index : nil,
              highlight_symbol: ">", highlight_style: tui.style(modifiers: [:reversed])
            )
          ]
        )
      end

      def self.render_search_bar(model, tui)
        return nil if model.focus != :search && model.search_query.empty?
        tui.block(
          title: "Search (Case-insensitive)", borders: [:all],
          border_style: model.focus == :search ? tui.style(fg: :cyan) : tui.style,
          children: [tui.paragraph(text: model.search_query)]
        )
      end

      def self.render_item_search_modal(model, tui, main_view)
        vp = tui.viewport_area
        height_pct = (([model.item_search_results.length, 1].max + 7).to_f / vp.height * 100).clamp(20, 80)
        
        tui.overlay(layers: [
          main_view,
          tui.center(width_percent: 80, height_percent: height_pct, child: tui.block(
            title: "Add Item", borders: [:all], border_style: tui.style(fg: :cyan),
            children: [
              tui.clear,
              tui.layout(direction: :vertical, constraints: [tui.constraint_length(3), tui.constraint_min(0)], children: [
                tui.block(title: "Query", borders: [:all], children: [tui.paragraph(text: model.item_search_query)]),
                tui.block(title: "Results", borders: [:all], children: [
                  tui.list(
                    items: model.item_search_results.map { |r| r[:name] },
                    selected_index: model.selected_item_search_index,
                    highlight_symbol: ">", highlight_style: tui.style(modifiers: [:reversed])
                  )
                ])
              ])
            ]
          ))
        ])
      end

      def self.render_quantity_modal(model, tui, main_view)
        item = model.item_search_results[model.selected_item_search_index]
        vp = tui.viewport_area
        height_pct = (8.0 / vp.height * 100).clamp(10, 40)

        tui.overlay(layers: [
          main_view,
          tui.center(width_percent: 50, height_percent: height_pct, child: tui.block(
            title: "Add Item - Quantity", borders: [:all], border_style: tui.style(fg: :cyan),
            children: [
              tui.clear,
              tui.layout(direction: :vertical, constraints: [tui.constraint_length(1), tui.constraint_length(3)], children: [
                tui.paragraph(text: "Item: #{item[:name]}"),
                tui.block(title: "Quantity", borders: [:all], children: [tui.paragraph(text: model.quantity_input)])
              ])
            ]
          ))
        ])
      end

      # --- Update Helpers ---

      def self.update_inventory(msg, model)
        items = filtered_and_sorted_items(model)
        idx = model.selected_inventory_index
        max = [0, items.length - 1].max

        if msg.up_arrow? || msg.k? then model.with(selected_inventory_index: (idx - 1).clamp(0, max))
        elsif msg.down_arrow? || msg.j? then model.with(selected_inventory_index: (idx + 1).clamp(0, max))
        elsif msg.home? then model.with(selected_inventory_index: 0)
        elsif msg.end? then model.with(selected_inventory_index: max)
        elsif msg.page_up? then model.with(selected_inventory_index: (idx - 10).clamp(0, max))
        elsif msg.page_down? then model.with(selected_inventory_index: (idx + 10).clamp(0, max))
        elsif msg.o?
          new_sort = { none: :name, name: :count, count: :none }[model.sort_order]
          model.with(sort_order: new_sort, selected_inventory_index: 0)
        else model
        end
      end

      def self.update_skills(msg, model)
        skills = model.profile.pmc.skills["Common"]
        idx = model.selected_skill_index
        max = skills.length - 1

        if msg.up_arrow? || msg.k? then model.with(selected_skill_index: (idx - 1).clamp(0, max))
        elsif msg.down_arrow? || msg.j? then model.with(selected_skill_index: (idx + 1).clamp(0, max))
        elsif msg.home? then model.with(selected_skill_index: 0)
        elsif msg.end? then model.with(selected_skill_index: max)
        elsif msg.page_up? then model.with(selected_skill_index: (idx - 10).clamp(0, max))
        elsif msg.page_down? then model.with(selected_skill_index: (idx + 10).clamp(0, max))
        elsif msg.plus? || msg.equals?
          skills[idx]["Progress"] += 100
          model
        elsif msg.minus?
          skills[idx]["Progress"] = [0, skills[idx]["Progress"] - 100].max
          model
        else model
        end
      end

      def self.update_search(msg, model)
        if msg.enter? then model.with(focus: :inventory)
        elsif msg.esc? then model.with(focus: :inventory, search_query: "")
        elsif msg.backspace? then model.with(search_query: model.search_query[0...-1])
        elsif msg.char then model.with(search_query: model.search_query + msg.char)
        else model
        end
      end

      def self.update_item_search(msg, model)
        results = model.item_search_results
        idx = model.selected_item_search_index
        max = [0, results.length - 1].max

        if msg.enter? then results.empty? ? model : model.with(focus: :quantity_input, quantity_input: "1")
        elsif msg.esc? then model.with(focus: :inventory, item_search_query: "", item_search_results: [], selected_item_search_index: 0)
        elsif msg.up_arrow? || msg.k? then model.with(selected_item_search_index: (idx - 1).clamp(0, max))
        elsif msg.down_arrow? || msg.j? then model.with(selected_item_search_index: (idx + 1).clamp(0, max))
        elsif msg.home? then model.with(selected_item_search_index: 0)
        elsif msg.end? then model.with(selected_item_search_index: max)
        elsif msg.page_up? then model.with(selected_item_search_index: (idx - 10).clamp(0, max))
        elsif msg.page_down? then model.with(selected_item_search_index: (idx + 10).clamp(0, max))
        elsif msg.backspace? || msg.char
          new_query = msg.backspace? ? model.item_search_query[0...-1] : model.item_search_query + msg.char
          model.with(item_search_query: new_query, item_search_results: model.editor.search_item(new_query), selected_item_search_index: 0)
        else model
        end
      end

      def self.update_quantity_input(msg, model)
        if msg.enter?
          count = model.quantity_input.to_i
          if count.positive?
            item = model.item_search_results[model.selected_item_search_index]
            model.profile.pmc.inventory.add_item_by_id(item[:id], count)
            model.with(focus: :inventory, item_search_query: "", item_search_results: [], selected_item_search_index: 0)
          else model
          end
        elsif msg.esc? then model.with(focus: :item_search)
        elsif msg.backspace? then model.with(quantity_input: model.quantity_input[0...-1])
        elsif msg.char && msg.char.match?(/\d/) then model.with(quantity_input: model.quantity_input + msg.char)
        else model
        end
      end

      # --- Logic Helpers ---

      def self.filtered_and_sorted_items(model)
        items = model.profile.pmc.inventory.all_items
        items = items.select { |i| i.name.downcase.include?(model.search_query.downcase) } unless model.search_query.empty?
        case model.sort_order
        when :name then items.sort_by { |i| i.name.downcase }
        when :count then items.sort_by(&:count).reverse
        else items
        end
      end
    end
  end
end
