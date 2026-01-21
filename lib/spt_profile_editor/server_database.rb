# frozen_string_literal: true

require 'json'

module SptProfileEditor
  class ServerDatabase
    attr_reader :items, :quests, :traders, :globals, :locales

    def initialize(server_path)
      @server_path = server_path
      raise 'Server path not configured or invalid.' if @server_path.nil? || !Dir.exist?(@server_path)

      load_database
    end

    def search_items_by_name(query)
      return [] if query.nil? || query.strip.empty?
      
      downcased_query = query.downcase
      results = []

      @items.each do |id, item_data|
        # Only consider valid items (usually have a parent and properties)
        next unless item_data['_type'] == 'Item'
        
        name = @locales["#{id} Name"]
        next if name.nil?

        if name.downcase.include?(downcased_query)
          results << {
            id: id,
            name: name,
            props: item_data['_props']
          }
        end
      end
      results
    end

    private

    def load_database
      db_path = File.join(@server_path, 'SPT_Data', 'database')

      @items = load_json(File.join(db_path, 'templates', 'items.json'))
      @quests = load_json(File.join(db_path, 'templates', 'quests.json'))
      @globals = load_json(File.join(db_path, 'templates', 'globals.json'))
      @traders = load_traders(File.join(db_path, 'traders'))
      @locales = load_json(File.join(db_path, 'locales', 'global', 'en.json')) # Default to English
    end

    def load_json(file_path)
      return {} unless File.exist?(file_path)
      JSON.parse(File.read(file_path))
    end

    def load_traders(traders_path)
      traders = {}
      return traders unless Dir.exist?(traders_path)

      Dir.glob(File.join(traders_path, '*.json')).each do |trader_file|
        trader_id = File.basename(trader_file, '.json')
        traders[trader_id] = load_json(trader_file)
      end
      traders
    end
  end
end
