#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "spt_profile_editor"
require "spt_profile_editor/tui/app"

# Check environment
unless ENV["SPT_PATH"]
  ENV["SPT_PATH"] = "/home/zacsek/Games/tarkov/drive_c/SPTarkov/SPT"
end

unless ENV["SPT_PATH"] && Dir.exist?(ENV["SPT_PATH"])
  warn "Error: SPT_PATH environment variable is not set or invalid."
  warn "Please set it to the root of your SPT-AKI server installation."
  exit 1
end

SptProfileEditor::Tui::App.run
