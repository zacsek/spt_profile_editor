# frozen_string_literal: true

require 'spt_profile_editor'

RSpec.describe SptProfileEditor::ServerDatabase do
  let(:server_path) { '/dummy/path' }
  
  # Mock data
  let(:items_json) do
    {
      "item_1" => { "_id" => "item_1", "_type" => "Item", "_props" => { "Name" => "Item One Props" } },
      "item_2" => { "_id" => "item_2", "_type" => "Item", "_props" => { "Name" => "Item Two Props" } },
      "node_1" => { "_id" => "node_1", "_type" => "Node", "_props" => { "Name" => "Node Props" } } 
    }.to_json
  end
  
  let(:locales_json) do
    {
      "item_1 Name" => "Graphics Card",
      "item_2 Name" => "CPU Fan"
    }.to_json
  end

  before do
    # Mock File.exist? and File.read to return our JSON data without hitting the disk
    allow(Dir).to receive(:exist?).and_return(false)
    allow(Dir).to receive(:exist?).with(server_path).and_return(true)
    
    # Mock database folder check
    allow(File).to receive(:exist?).and_return(false) # Default to false
    
    db_path = File.join(server_path, 'SPT_Data', 'database')
    
    # Allow items.json read
    items_path = File.join(db_path, 'templates', 'items.json')
    allow(File).to receive(:exist?).with(items_path).and_return(true)
    allow(File).to receive(:read).with(items_path).and_return(items_json)

    # Allow locales read
    locales_path = File.join(db_path, 'locales', 'global', 'en.json')
    allow(File).to receive(:exist?).with(locales_path).and_return(true)
    allow(File).to receive(:read).with(locales_path).and_return(locales_json)
    
    # Allow other files to return empty JSON objects if read
    allow(File).to receive(:read).with(include("quests.json")).and_return("{}")
    allow(File).to receive(:read).with(include("globals.json")).and_return("{}")
    allow(Dir).to receive(:glob).and_return([])
  end

  subject { described_class.new(server_path) }

  describe '#search_items_by_name' do
    it 'finds items by exact name (case insensitive)' do
      results = subject.search_items_by_name("graphics card")
      expect(results.size).to eq(1)
      expect(results.first[:id]).to eq("item_1")
      expect(results.first[:name]).to eq("Graphics Card")
    end

    it 'finds items by partial name' do
      results = subject.search_items_by_name("graph")
      expect(results.size).to eq(1)
      expect(results.first[:name]).to eq("Graphics Card")
    end

    it 'ignores items with different types' do
      # Should not find "node_1" even if we search for it, because it's not type "Item"
      # But first, let's verify our mock setup logic for locales.
      # Since our locales mock only has item_1 and item_2, searching for "Node" should return nothing regardless.
      results = subject.search_items_by_name("Node")
      expect(results).to be_empty
    end

    it 'returns multiple matches' do
        # Let's add another item that matches "card" if possible, or just search for "a"
        results = subject.search_items_by_name("a")
        # "Graphics Card" and "CPU Fan" both have "a"
        expect(results.size).to eq(2)
    end

    it 'returns empty array for no matches' do
      results = subject.search_items_by_name("NonExistentItem")
      expect(results).to be_empty
    end
  end
end
