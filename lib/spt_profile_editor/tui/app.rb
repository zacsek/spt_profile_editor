# frozen_string_literal: true

require "rooibos"
require_relative "selector"
require_relative "editor"

module SptProfileEditor
  module Tui
    module App
      Model = Data.define(:screen, :selector_model, :editor_model, :editor)

      def self.init
        editor = SptProfileEditor::Editor.new
        selector_model = Selector.init(editor)
        Model.new(screen: :selector, selector_model: selector_model, editor_model: nil, editor: editor)
      end

      def self.view(model, tui)
        case model.screen
        when :selector then Selector.view(model.selector_model, tui)
        when :editor then Editor.view(model.editor_model, tui)
        end
      end

      def self.update(msg, model)
        case model.screen
        when :selector
          res = Selector.update(msg, model.selector_model)
          case res
          when Array
            action, data = res
            if action == :switch_to_editor
              model.with(screen: :editor, editor_model: Editor.init(data.profile, model.editor, data.id))
            else
              model
            end
          when Rooibos::Command::Custom then [model, res]
          else model.with(selector_model: res)
          end
        when :editor
          res = Editor.update(msg, model.editor_model)
          case res
          when :back then model.with(screen: :selector)
          when Rooibos::Command::Custom then [model, res]
          else model.with(editor_model: res)
          end
        end
      end

      def self.run
        Rooibos.run(self)
      end

      Init = method(:init)
      View = method(:view)
      Update = method(:update)
    end
  end
end
