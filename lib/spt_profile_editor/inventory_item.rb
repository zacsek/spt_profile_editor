# frozen_string_literal: true

module SptProfileEditor
  # Wraps a single item hash from the inventory.
  class InventoryItem
    attr_reader :data

    def initialize(item_hash, database)
      @data = item_hash
      @db = database
    end

    def id
      @data['_id']
    end

    def tpl
      @data['_tpl']
    end

    def parent_id
      @data['parentId']
    end

    def slot_id
      @data['slotId']
    end

    def location
      @data['location']
    end

    def upd
      @data['upd']
    end

    def count
      upd&.[]('StackObjectsCount') || 1
    end

    def count=(new_count)
      @data['upd'] ||= {}
      @data['upd']['StackObjectsCount'] = new_count
    end

    def name
      @db.locales["#{tpl} Name"] || tpl
    end

    def description
      @db.locales["#{tpl} Description"] || "No description for #{tpl}"
    end

    def is_money?
        @db.items[tpl]['_parent'] == '543be5dd4bdc2d3c308b4569'
    end
  end
end
