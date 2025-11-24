module Ollama
  module SchemaDefinitions
    # JSON schema for single official evaluation responses
    # Used when evaluating one official for one specific position
    EVALUATION_SCHEMA = {
      type: "object",
      required: ["score", "reasoning"],
      properties: {
        score: {
          type: "integer",
          minimum: 0,
          maximum: 100,
          description: "Match quality score from 0 to 100"
        },
        reasoning: {
          type: "string",
          description: "Brief explanation of the score"
        }
      },
      additionalProperties: false
    }.freeze

    # JSON schema for multiple assignment responses
    # Used when assigning multiple positions for one or more games
    ASSIGNMENT_SCHEMA = {
      type: "object",
      required: ["assignments", "summary"],
      properties: {
        assignments: {
          type: "array",
          items: {
            type: "object",
            required: ["game_id", "role", "official_id", "score", "reasoning"],
            properties: {
              game_id: {
                type: "integer",
                description: "ID of the game"
              },
              role: {
                type: "string",
                description: "Role name (referee, umpire, etc.)"
              },
              official_id: {
                type: "integer",
                description: "ID of the official"
              },
              score: {
                type: "integer",
                minimum: 0,
                maximum: 100,
                description: "Match quality score"
              },
              reasoning: {
                type: "string",
                description: "Brief explanation of why this official was chosen"
              }
            },
            additionalProperties: false
          }
        },
        summary: {
          type: "string",
          description: "Overall assignment strategy explanation"
        }
      },
      additionalProperties: false
    }.freeze
  end
end
