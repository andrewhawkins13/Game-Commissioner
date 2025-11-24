require "rails_helper"

RSpec.describe Ollama::PromptRendererService do
  let(:test_template_dir) { Rails.root.join("tmp", "test_prompts") }
  let(:test_template_path) { test_template_dir.join("test_template.j2") }

  before do
    # Create test template directory
    FileUtils.mkdir_p(test_template_dir)
  end

  after do
    # Clean up test templates
    FileUtils.rm_rf(test_template_dir) if test_template_dir.exist?
  end

  describe ".render" do
    context "with simple template" do
      before do
        template_content = "Hello <%= name %>, you have <%= count %> messages."
        File.write(test_template_path, template_content)

        # Temporarily change the template location for this test
        allow(Rails.root).to receive(:join).with("app", "prompts", "test_template.j2").and_return(test_template_path)
      end

      it "renders template with provided data" do
        data = { name: "John", count: 5 }
        result = described_class.render("test_template", data)

        expect(result).to eq("Hello John, you have 5 messages.")
      end
    end

    context "with complex template using trim mode" do
      before do
        template_content = <<~TEMPLATE
          Name: <%= name %>
          <%- if active -%>
          Status: Active
          <%- else -%>
          Status: Inactive
          <%- end -%>
          Items:
          <%- items.each do |item| -%>
          - <%= item %>
          <%- end -%>
        TEMPLATE
        File.write(test_template_path, template_content)

        allow(Rails.root).to receive(:join).with("app", "prompts", "test_template.j2").and_return(test_template_path)
      end

      it "renders template with trim mode correctly" do
        data = { name: "Test", active: true, items: ["Item 1", "Item 2"] }
        result = described_class.render("test_template", data)

        expect(result).to include("Name: Test")
        expect(result).to include("Status: Active")
        expect(result).to include("- Item 1")
        expect(result).to include("- Item 2")
      end
    end

    context "when template does not exist" do
      it "raises an error" do
        expect {
          described_class.render("nonexistent_template", {})
        }.to raise_error(/Template not found/)
      end
    end

    context "verifying template files exist" do
      it "verifies assign_game_positions template exists" do
        template_path = Rails.root.join("app", "prompts", "assign_game_positions.j2")
        expect(File.exist?(template_path)).to be true
      end
    end
  end

  describe ".render_game_positions" do
    it "calls render with correct template name" do
      data = { test: "data" }
      expect(described_class).to receive(:render).with("assign_game_positions", data)

      described_class.render_game_positions(data)
    end
  end
end
