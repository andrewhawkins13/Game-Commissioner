# Game Commissioner Project Rules

This document contains project-specific conventions and guidelines for working with Claude Code in this Rails application.

## Table of Contents
- [Database & Migrations](#database--migrations)
- [Service Object Architecture](#service-object-architecture)
- [Testing Requirements](#testing-requirements)
- [Code Quality & Style](#code-quality--style)
- [AI & Prompt Management](#ai--prompt-management)
- [Rails 8 Patterns](#rails-8-patterns)
- [Code Organization](#code-organization)

---

## Database & Migrations

### Never Modify Existing Migrations
**CRITICAL:** Do not edit or update existing migration files. Once a migration has been run (committed to the repository), it has already been executed in other environments.

**Instead:**
- Create a new migration to modify tables, columns, or indexes
- Use `rails generate migration` for schema changes
- Example: Instead of editing `20240101_create_games.rb`, create `20250122_add_column_to_games.rb`

**Why:** Changing existing migrations will cause deployment failures since they've already been applied to production databases.

### Schema Changes
- Always run migrations after creating them to verify they work
- Check `db/schema.rb` to confirm expected changes
- Consider data migrations separately from schema migrations

---

## Service Object Architecture

This project uses a service-oriented architecture with clear separation of concerns.

### Service Namespaces

**AI Assignment Services** (`app/services/ai_assignment/`)
- `AiAssignment::Orchestrator` - Coordinates assignment workflows
- `AiAssignment::CandidateFinder` - Identifies potential officials
- `AiAssignment::EligibilityFilter` - Applies constraint filtering
- `AiAssignment::Evaluator` - Assesses assignment quality

**Ollama Services** (`app/services/ollama/`)
- `Ollama::Client` - HTTP communication with Ollama API
- `Ollama::PromptBuilder` - Constructs prompts from templates
- `Ollama::ResponseParser` - Parses and validates LLM responses
- `Ollama::SchemaDefinitions` - JSON schema definitions

**Business Rules Services** (`app/services/business_rules/`)
- `BusinessRules::SchedulingConflictChecker` - Validates scheduling constraints

**Standalone Services**
- `DistanceCalculationService` - Haversine distance calculations

### Service Conventions

1. **Single Responsibility:** Each service has one clear purpose
2. **Dependency Injection:** Pass dependencies as constructor arguments
3. **Return Values:** Use result objects or explicit success/failure responses
4. **Error Handling:** Raise meaningful exceptions; log errors appropriately

**Example Service Pattern:**
```ruby
module AiAssignment
  class CandidateFinder
    def initialize(game:, official_pool:)
      @game = game
      @official_pool = official_pool
    end

    def call
      # Service logic here
    end

    private

    attr_reader :game, :official_pool
  end
end
```

### When to Create Services

Create a service when:
- Logic spans multiple models
- Complex business rules need testing in isolation
- External API integration (like Ollama)
- Background job coordination
- Multi-step workflows

**Don't over-service:** Simple CRUD operations belong in controllers/models.

---

## Testing Requirements

### Write Tests for Everything

**Always include tests when:**
- Creating new models, services, or controllers
- Modifying existing business logic
- Adding new features or endpoints
- Fixing bugs (write failing test first)

### RSpec Conventions

**Structure:**
- Model specs in `spec/models/`
- Service specs in `spec/services/` (mirror service namespaces)
- Controller specs in `spec/controllers/`
- Request specs for integration tests

**Use Factory Bot:**
```ruby
# spec/factories/games.rb
FactoryBot.define do
  factory :game do
    name { "Championship Game" }
    game_date { 2.days.from_now }
    location { "Main Stadium" }
    status { :open }
  end
end
```

**Test Organization:**
```ruby
RSpec.describe AiAssignment::CandidateFinder do
  describe "#call" do
    context "with available officials" do
      it "returns eligible candidates" do
        # Test implementation
      end
    end

    context "with no available officials" do
      it "returns empty array" do
        # Test implementation
      end
    end
  end
end
```

### Testing AI/LLM Code

- Use WebMock to stub Ollama API calls
- Create fixture responses in `spec/fixtures/`
- Test prompt building separately from API calls
- Verify error handling for malformed LLM responses

---

## Code Quality & Style

### RuboCop Rails Omakase

All code must pass RuboCop with the Rails Omakase configuration.

**Before committing:**
```bash
bundle exec rubocop
```

**Auto-fix safe violations:**
```bash
bundle exec rubocop -a
```

### Key Style Conventions

- Follow Rails conventions for naming and structure
- Use Ruby 3.3.4 syntax features
- Prefer readability over cleverness
- Keep methods small and focused
- Use meaningful variable names

### Security

The project runs automated security scans (Brakeman, Bundler Audit). Ensure:
- No SQL injection vulnerabilities
- Proper parameter sanitization
- Secure secret management (.env files, not committed)
- No hardcoded credentials

---

## AI & Prompt Management

### Prompt Template Structure

Prompts are stored in `app/prompts/` as Jinja2 templates (`.j2` extension).

**Main Prompts:**
- `assign_all_positions.j2` - Multi-position assignment
- `assign_single_game.j2` - Single game assignment
- `evaluate_attempt.j2` - Assignment quality evaluation
- `evaluate_official.j2` - Individual official assessment

**Partials:**
- `app/prompts/partials/` - Reusable prompt components

### Prompt Conventions

1. **Use Jinja2 syntax** for variable interpolation: `{{ variable_name }}`
2. **Keep prompts focused** on single tasks
3. **Provide clear context** and constraints to the LLM
4. **Include examples** when beneficial for LLM understanding
5. **Use partials** for repeated prompt sections

### Ollama Integration

**Model Configuration:**
- Default model: Defined in application configuration
- Temperature and parameters: Set via `Ollama::Client`
- Response format: JSON with structured schemas

**Example Usage:**
```ruby
builder = Ollama::PromptBuilder.new(template: "assign_single_game")
prompt = builder.build(game: @game, officials: @officials)

client = Ollama::Client.new
response = client.generate(prompt: prompt, schema: assignment_schema)

parser = Ollama::ResponseParser.new(response)
result = parser.parse
```

### Schema Definitions

Define JSON schemas in `Ollama::SchemaDefinitions` for structured LLM responses. This ensures type safety and validation.

---

## Rails 8 Patterns

### Hotwire Stack

**Turbo Streams:**
- Use for real-time UI updates
- Broadcast from models or background jobs
- Keep stream names consistent with resource naming

**Turbo Frames:**
- Lazy-load page sections
- Inline editing without full page refreshes

**Stimulus Controllers:**
- Keep JavaScript organized and scoped
- Place in `app/javascript/controllers/`
- Use data attributes for configuration

### Solid Queue (Background Jobs)

**Job Conventions:**
```ruby
class AssignOpenGamesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Job logic
  end
end
```

**When to use jobs:**
- Long-running operations (LLM calls, batch processing)
- Scheduled tasks
- Async operations that don't block user requests

### Solid Cache & Solid Cable

- Leverage database-backed caching for expensive operations
- Use ActionCable (Solid Cable) for real-time features
- Cache LLM responses when appropriate

### Asset Management

**Importmap:**
- JavaScript dependencies via `config/importmap.rb`
- Pin external libraries explicitly
- No npm/node_modules in this project

**Tailwind CSS:**
- Utility-first styling
- Follow existing component patterns
- Keep custom CSS minimal

---

## Code Organization

### Model Concerns

Place shared model behavior in `app/models/concerns/`:
```ruby
module Assignable
  extend ActiveSupport::Concern

  included do
    # Shared logic
  end
end
```

### Controller Patterns

- Keep controllers thin
- Delegate business logic to services
- Use strong parameters for mass assignment protection
- Follow RESTful conventions

**Standard CRUD Actions:**
- `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`

### View Organization

- Use partials for reusable components: `_game_card.html.erb`
- Keep logic out of views (use helpers or presenters)
- Leverage Turbo Frames and Streams for dynamic content

### File Naming Conventions

- Models: `app/models/game.rb` (singular)
- Controllers: `app/controllers/games_controller.rb` (plural)
- Services: `app/services/ai_assignment/orchestrator.rb` (namespaced)
- Jobs: `app/jobs/assign_open_games_job.rb` (ends in `_job`)
- Specs: Mirror source file paths in `spec/`

---

## Common Workflows

### Adding a New Feature

1. Write failing tests first (TDD)
2. Create service objects for complex logic
3. Update models/controllers as needed
4. Add Stimulus controller if JavaScript needed
5. Run RuboCop and fix violations
6. Ensure all tests pass
7. Commit with clear message

### Modifying Database Schema

1. Generate migration: `rails generate migration AddColumnToTable`
2. Edit migration file
3. Run migration: `rails db:migrate`
4. Update model validations/associations
5. Add/update tests
6. Commit migration and related changes together

### Working with AI Prompts

1. Edit `.j2` template in `app/prompts/`
2. Test prompt via `Ollama::PromptBuilder` in console
3. Validate response parsing
4. Add/update tests for prompt-related services
5. Monitor LLM response quality

---

## Quick Reference

### Run Tests
```bash
bundle exec rspec
```

### Run Linter
```bash
bundle exec rubocop
```

### Start Development Server
```bash
bin/dev
```

### Database Operations
```bash
rails db:create
rails db:migrate
rails db:seed
rails db:reset  # Drop, create, migrate, seed
```

### Background Jobs
```bash
bin/jobs  # Start Solid Queue worker
```

### Console
```bash
rails console
```

---

**Remember:** These rules ensure code consistency, maintainability, and successful deployments. When in doubt, follow existing patterns in the codebase.
