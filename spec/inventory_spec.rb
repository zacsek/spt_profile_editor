# frozen_string_literal: true

require 'spt_profile_editor'
require 'json'

RSpec.describe SptProfileEditor::Inventory do
  let(:profile_path) { 'spec/fixtures/profile.json' }
  let(:raw_profile) { JSON.parse(File.read(profile_path)) }
  
  # Create a mock database object
  let(:mock_db) do
    instance_double(SptProfileEditor::ServerDatabase,
      items: {
        "5449016a4bdc2d6f028b456f" => { "_parent" => "543be5dd4bdc2d3c308b4569", "_props" => { "StackMaxSize" => 500000 } }, # Roubles
        "5d235b4d86f7742e017bc88a" => { "_parent" => "543be5dd4bdc2d3c308b4569", "_props" => { "StackMaxSize" => 50 } }  # GPUs (Simulated stackable)
      },
      locales: {
        "5449016a4bdc2d6f028b456f Name" => "Roubles"
      }
    )
  end

  let(:inventory) do
    pmc_inventory_hash = raw_profile['characters']['pmc']['Inventory']
    SptProfileEditor::Inventory.new(pmc_inventory_hash, mock_db)
  end

  describe '#stash_items' do
    it 'returns only items directly in the stash' do
      expect(inventory.stash_items.size).to eq(1)
      expect(inventory.stash_items.first.tpl).to eq('5449016a4bdc2d6f028b456f') # Roubles tpl
    end
  end

  describe '#money' do
    it 'lists all money items in the stash' do
        expect(inventory.money.size).to eq(1)
        expect(inventory.money.first.name).to eq("Roubles")
        expect(inventory.money.first.count).to eq(1000)
    end
  end

  describe '#add_money' do
    it 'adds to an existing stack of money' do
      roubles_tpl = "5449016a4bdc2d6f028b456f"
      
      # Verify initial state
      initial_roubles = inventory.money.find { |m| m.tpl == roubles_tpl }
      expect(initial_roubles.count).to eq(1000)

      # Add money
      inventory.add_money(roubles_tpl, 500)
      
      # Verify final state
      final_roubles = inventory.money.find { |m| m.tpl == roubles_tpl }
      expect(final_roubles.count).to eq(1500)
    end

    it 'creates a new stack if one does not exist' do
      gpu_tpl = "5d235b4d86f7742e017bc88a" # Not really money, but works for this test
      
      # Verify initial state
      expect(inventory.all_items.find { |i| i.tpl == gpu_tpl }).to be_nil

      # Add "money"
      inventory.add_money(gpu_tpl, 10)
      
      # Verify final state
      new_stack = inventory.all_items.find { |i| i.tpl == gpu_tpl }
      expect(new_stack).not_to be_nil
      expect(new_stack.count).to eq(10)
      expect(new_stack.parent_id).to eq(inventory.stash_id)
    end
  end

  describe '#generate_new_id' do
    it 'creates a 24-character hexadecimal ID' do
      new_id = inventory.send(:generate_new_id) # testing a private method
      expect(new_id.length).to eq(24)
      expect(new_id).to match(/^[0-9a-f]{24}$/)
    end

    it 'creates a unique ID' do
      id1 = inventory.send(:generate_new_id)
      id2 = inventory.send(:generate_new_id)
      expect(id1).not_to eq(id2)
    end
  end
end
