# frozen_string_literal: true

require_relative 'inventory_item'

module SptProfileEditor
  # Manages the character's inventory.
  class Inventory
    def initialize(inventory_hash, database)
      @data = inventory_hash
      @db = database
      @items = @data['items'].map { |item_hash| InventoryItem.new(item_hash, @db) }
    end

    def stash_id
      @data['stash']
    end

    def all_items
      @items
    end

    def stash_items
      @items.select { |item| item.parent_id == stash_id }
    end

    def money
      stash_items.select { |item| item.is_money? }
    end
    
    def add_money(tpl, amount)
      # Find if there is already a stack of this money in the inventory
      money_stack = money.find { |item| item.tpl == tpl }
      if money_stack
        money_stack.count += amount
      else
        # If no stack exists, we need to create a new item.
        # This is a simplified version. A full implementation needs to find a free slot.
        new_id = generate_new_id
        new_item_hash = {
          "_id" => new_id,
          "_tpl" => tpl,
          "parentId" => stash_id,
          "slotId" => "hideout",
          "location" => { "x" => 0, "y" => 0, "r" => "Horizontal" }, # Placeholder location
          "upd" => { "StackObjectsCount" => amount }
        }
        @data['items'] << new_item_hash
        @items << InventoryItem.new(new_item_hash, @db)
        puts "Warning: Added new money stack at placeholder location [0,0]. Full slot finding not implemented."
      end
    end

    private
    
    def generate_new_id
      existing_ids = @items.map(&:id)
      new_id = nil
      loop do
        time = Time.now
        random = rand(100_000_000..999_999_999).to_s
        ret_val = format('%02d%02d%02d%02d%02d%s', time.month, time.day, time.hour, time.min, time.sec, random)
        
        sign_length = 24 - ret_val.length
        sign = sign_length.times.map { "0123456789abcdef"[rand(16)] }.join
        
        new_id = ret_val + sign
        break unless existing_ids.include?(new_id)
      end
      new_id
    end
  end
end
