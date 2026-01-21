# frozen_string_literal: true

require_relative 'inventory'

module SptProfileEditor
  # Represents the entire user profile.
  class Profile
    attr_reader :data
    attr_accessor :characters, :user_builds, :customisation_unlocks

    def initialize(data_hash, database)
      @data = data_hash
      @db = database
      @characters = CharacterSet.new(data_hash['characters'] || {}, @db)
      @user_builds = data_hash['userbuilds'] || {}
      @customisation_unlocks = data_hash['customisationUnlocks'] || []
    end

    def pmc
      @characters.pmc
    end

    def scav
      @characters.scav
    end
  end

  # A container for the PMC and Scav characters.
  class CharacterSet
    attr_accessor :pmc, :scav

    def initialize(hash, database)
      @pmc = Character.new(hash['pmc'] || {}, database)
      @scav = Character.new(hash['scav'] || {}, database)
    end
  end

  # Represents a single character (PMC or Scav).
  class Character
    attr_accessor :data

    def initialize(data_hash, database)
      @data = data_hash
      @db = database
      @inventory = Inventory.new(@data['Inventory'], @db) if @data['Inventory']
    end

    def info
      @data['Info']
    end

    def health
      @data['Health']
    end

    def skills
      @data['Skills']
    end

    def inventory
      @inventory
    end

    def quests
      @data['Quests']
    end

    def level
      info['Level']
    end

    def level=(new_level)
      info['Level'] = new_level
    end

    def nickname
      info['Nickname']
    end
  end
end
