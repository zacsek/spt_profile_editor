# frozen_string_literal: true

require "json"

module SptProfileEditor
  # Wraps a single item hash from the inventory.
  class InventoryItem
    attr_reader :data

    def initialize(item_hash, database)
      @data = item_hash
      @db = database
    end

    def [](key)
      @data[key]
    end

    def to_s
      JSON.pretty_generate(@data)
    end

    def id
      @data["_id"]
    end

    def tpl
      @data["_tpl"]
    end

    def parent_id
      @data["parentId"]
    end

    def slot_id
      @data["slotId"]
    end

    def location
      @data["location"]
    end

    def upd
      @data["upd"]
    end

    def count
      upd&.[]("StackObjectsCount") || 1
    end

    def count=(new_count)
      @data["upd"] ||= {}
      @data["upd"]["StackObjectsCount"] = new_count
    end

    def name
      @db.locales["#{tpl} Name"] || tpl
    end

    def short
      @db.locales["#{tpl} ShortName"] || tpl
    end

    def description
      @db.locales["#{tpl} Description"] || "No description for #{tpl}"
    end

    def is_money?
      is_rouble? # || is_dollar? || is_euro? || is_gp? || is_bitcoin?
    end

    def is_rouble?
      @db.items[tpl]&.[]("_parent") == "543be5dd4bdc2d3c308b4569"
    end

    def is_dollar?
      @db.items[tpl]&.[]("_parent") == "5696686a4bdc2da3298b456a"
    end

    def is_euro?
      @db.items[tpl]&.[]("_parent") == "569668774bdc2da2298b4568"
    end

    def is_gp?
      @db.items[tpl]&.[]("_parent") == "5d235b4d86f7742e017bc88a"
    end

    def is_bitcoin?
      @db.items[tpl]&.[]("_parent") == "59faff1d86f7746c51718c9c"
    end

    def inspect
      "#<#{self.class} id=#{id} tpl=#{tpl} name=\"#{name}\" count=#{count}>"
    end
  end
end
