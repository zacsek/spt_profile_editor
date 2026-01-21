# frozen_string_literal: true

RSpec.describe SptProfileEditor do
  it "has a version number" do
    expect(SptProfileEditor::VERSION).not_to be nil
  end

  it "can be initialized" do
    # Mock the ServerDatabase to avoid needing a real path for this test
    allow(SptProfileEditor::ServerDatabase).to receive(:new).and_return(instance_double(SptProfileEditor::ServerDatabase))
    
    # Provide a dummy path
    editor = SptProfileEditor::Editor.new('/dummy/path')
    expect(editor).to be_a(SptProfileEditor::Editor)
  end
end
