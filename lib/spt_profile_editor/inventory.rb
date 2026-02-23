# frozen_string_literal: true

require_relative "inventory_item"

module SptProfileEditor
  # Manages the character's inventory.
  class Inventory
    include Enumerable

    def initialize(inventory_hash, database)
      @data = inventory_hash
      @db = database
      @items = @data["items"].map { |item_hash| InventoryItem.new(item_hash, @db) }
    end

    def each(&block)
      @items.each(&block)
    end

    def delete_item(item_id)
      item = @items.find { |i| i.id == item_id }
      return false unless item

      @items.delete(item)
      @data["items"].reject! { |i| i["_id"] == item_id }
      true
    end

    def search_item(query)
      return [] if query.nil? || query.strip.empty?
      
      downcased_query = query.downcase
      results = []
      
      @items.each do |item|
        results << item if item.name.downcase.include?(downcased_query)
      end

      results
    end

    def delete_items_by_name(query)
      search_item(query).each do |item|
        delete_item(item.id)
      end
    end

    def inspect
      "#<#{self.class} items_count=#{@items.size} stash_id=#{stash_id}>"
    end

    def stash_id
      @data["stash"]
    end

    def all_items
      @items
    end

    def stash_items
      @items.select { |item| item.parent_id == stash_id }
    end

    def money
      stash_items.select(&:is_money?)
    end

    def add_money(tpl, amount)
      add_item_by_id(tpl, amount)
    end

    def add_item_by_id(tpl, count)
      item_info = @db.items[tpl]
      raise "Item #{tpl} not found in database" unless item_info

      stack_max_size = item_info.dig("_props", "StackMaxSize") || 1

      if stack_max_size > 1
        # Stackable: Try to merge into existing stacks first
        existing_stacks = stash_items.select { |item| item.tpl == tpl }

        existing_stacks.each do |stack|
          break if count <= 0

          space = stack_max_size - stack.count
          next if space <= 0

          to_add = [count, space].min
          stack.count += to_add
          count -= to_add
        end

        # Create new stacks for remaining count
        while count.positive?
          to_create = [count, stack_max_size].min
          create_item_entry(tpl, to_create)
          count -= to_create
        end
      else
        # Not stackable: Create 'count' individual items
        count.times { create_item_entry(tpl, 1) }
      end
    end

    private

    def create_item_entry(tpl, count)
      new_id = generate_new_id
      new_item_hash = {
        "_id" => new_id,
        "_tpl" => tpl,
        "parentId" => stash_id,
        "slotId" => "hideout",
        "location" => { "x" => 0, "y" => 0, "r" => "Horizontal" }, # Placeholder location
        "upd" => { "StackObjectsCount" => count, "SpawnedInSession" => true }
      }

      # Remove StackObjectsCount for non-stackables to be cleaner?
      # The game usually expects it strictly for stackables.
      # If count is 1 and it's not stackable, usually 'upd' might assume SpawnedInSession or just be empty.
      # But sticking to the requested logic.

      @data["items"] << new_item_hash
      @items << InventoryItem.new(new_item_hash, @db)
      # puts "Warning: Added item #{tpl} (count: #{count}) at placeholder location."
    end

    def generate_new_id
      existing_ids = @items.map(&:id)
      new_id = nil
      loop do
        time = Time.now
        random = rand(100_000_000..999_999_999).to_s
        ret_val = format("%02d%02d%02d%02d%02d%s", time.month, time.day, time.hour, time.min, time.sec, random)

        sign_length = 24 - ret_val.length
        sign = sign_length.times.map { "0123456789abcdef"[rand(16)] }.join

        new_id = ret_val + sign
        break unless existing_ids.include?(new_id)
      end
      new_id
    end
  end
end
