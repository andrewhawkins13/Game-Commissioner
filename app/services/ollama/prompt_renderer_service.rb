module Ollama
  class PromptRendererService
    # Render a template with provided data
    # @param template_name [String] Name of the template file (without .j2 extension)
    # @param data [Hash] Data to pass to the template
    # @return [String] Rendered template
    def self.render(template_name, data)
      template_path = Rails.root.join("app", "prompts", "#{template_name}.j2")

      unless File.exist?(template_path)
        raise "Template not found: #{template_path}"
      end

      template_content = File.read(template_path)

      # Create a binding with the data
      binding_obj = create_binding_with_data(data)

      # Render the ERB template with trim mode
      ERB.new(template_content, trim_mode: "-").result(binding_obj)
    end

    # Render the game positions assignment template
    # @param data [Hash] Data from PromptBuilderService.build_single_game_data
    # @return [String] Rendered prompt
    def self.render_game_positions(data)
      render("assign_game_positions", data)
    end

    private

    # Render a partial template (used within templates)
    # @param partial_name [String] Name of the partial file (without .j2 extension or leading _)
    # @param binding_obj [Binding] The binding from the parent template
    # @return [String] Rendered partial
    def self.render_partial(partial_name, binding_obj)
      partial_path = Rails.root.join("app", "prompts", "partials", "_#{partial_name}.j2")

      unless File.exist?(partial_path)
        raise "Partial not found: #{partial_path}"
      end

      partial_content = File.read(partial_path)
      ERB.new(partial_content, trim_mode: "-").result(binding_obj)
    end

    # Create a binding object with data accessible as local variables
    # @param data [Hash] Data hash
    # @return [Binding] Binding with data
    def self.create_binding_with_data(data)
      # Create a new object to hold the binding
      obj = Object.new

      # Define methods on the singleton class for each data key
      data.each do |key, value|
        obj.define_singleton_method(key) { value }
      end

      # Make render_partial available within templates
      obj.define_singleton_method(:render_partial) do |partial_name|
        PromptRendererService.render_partial(partial_name, binding)
      end

      # Return the binding
      obj.instance_eval { binding }
    end
  end
end
