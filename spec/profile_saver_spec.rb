# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe SptProfileEditor::ProfileSaver do
  let(:profile_data) { { 'characters' => { 'pmc' => { 'Info' => { 'Level' => 1 } } } } }
  let(:profile_double) { instance_double(SptProfileEditor::Profile, data: profile_data) }
  let(:saver) { described_class.new(profile_double, nil) }

  describe '#save' do
    it 'creates a backup and saves the file' do
      Dir.mktmpdir do |dir|
        original_path = File.join(dir, 'profile.json')
        target_path = File.join(dir, 'profile.json')
        
        # Write initial file
        File.write(original_path, JSON.generate({ 'old' => 'data' }))
        
        # Perform save
        saver.save(original_path, target_path)
        
        # Check for backup
        backups = Dir.glob(File.join(dir, 'profile.json_backup_*'))
        expect(backups).not_to be_empty
        
        # Check content of backup
        expect(File.read(backups.first)).to include('old', 'data')
        
        # Check target file content (should be new data)
        saved_data = JSON.parse(File.read(target_path))
        expect(saved_data['characters']['pmc']['Info']['Level']).to eq(1)
      end
    end
  end
end
