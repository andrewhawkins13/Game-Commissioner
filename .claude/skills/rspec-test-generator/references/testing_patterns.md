# Game Commissioner RSpec Testing Patterns Reference

Comprehensive guide to RSpec testing conventions used in the Game Commissioner Rails application.

## Table of Contents
- [Project Testing Philosophy](#project-testing-philosophy)
- [Test Data Management](#test-data-management)
- [Mocking and Stubbing](#mocking-and-stubbing)
- [Geocoder Testing](#geocoder-testing)
- [WebMock for HTTP Requests](#webmock-for-http-requests)
- [Model Testing Patterns](#model-testing-patterns)
- [Service Testing Patterns](#service-testing-patterns)
- [Controller Testing Patterns](#controller-testing-patterns)
- [Job Testing Patterns](#job-testing-patterns)
- [Common Matchers and Expectations](#common-matchers-and-expectations)

---

## Project Testing Philosophy

### Core Principles

1. **No Factory Bot Usage**: Despite `factory_bot_rails` being in Gemfile, this project does NOT use factories
   - Models use real ActiveRecord objects created with `.create!`
   - Services use RSpec doubles extensively
   - This is an established pattern; maintain consistency

2. **Comprehensive Coverage**: Test all scenarios
   - Happy path (expected behavior)
   - Error conditions (what happens when things fail)
   - Edge cases (nil values, empty arrays, boundary conditions)
   - Database constraints (uniqueness enforced at DB level)

3. **Isolation Through Mocking**: Services are tested in isolation
   - External dependencies are mocked with doubles
   - HTTP requests are stubbed with WebMock
   - Focus on the unit under test

4. **Real Database for Models**: Model tests use real ActiveRecord
   - Leverage transactional fixtures for rollback
   - Test actual database constraints
   - Verify geocoding integration

---

## Test Data Management

### Models: Use Real ActiveRecord Objects

```ruby
# Create test models with .create!
let(:game) do
  Game.create!(
    name: "Championship Game",
    game_date: 2.days.from_now,
    location: "Main Stadium",
    address: "123 Test St",
    status: :open
  )
end

let(:official) do
  Official.create!(
    name: "John Doe",
    email: "john@example.com",
    phone: "555-1234",
    max_distance: 50
  )
end
```

**Why?**
- Tests actual database behavior
- Catches validation issues
- Verifies association setup
- Simulates production environment

### Services: Use RSpec Doubles

```ruby
# Create type-hinted doubles
let(:game) do
  double("Game",
    id: 1,
    name: "Test Game",
    game_date: Time.current,
    status: "open",
    address: "123 Test St"
  )
end

let(:official) do
  double("Official",
    id: 10,
    name: "Jane Smith",
    email: "jane@example.com",
    max_distance: 50
  )
end

# ActiveRecord relation doubles
let(:games_relation) { double("ActiveRecord::Relation") }
let(:officials_relation) { double("ActiveRecord::Relation") }
```

**Why?**
- Fast test execution
- Isolates service logic
- No database dependency
- Clear test intent

---

## Mocking and Stubbing

### Method Stubbing

```ruby
# Basic stub
allow(object).to receive(:method).and_return(value)

# Stub with arguments
allow(object).to receive(:method).with(arg1, arg2).and_return(value)

# Stub with hash arguments
allow(object).to receive(:method).with(hash_including(key: value))

# Stub to raise error
allow(object).to receive(:method).and_raise(StandardError.new("Error message"))

# Stub chain
allow(Game).to receive(:upcoming).and_return(games_relation)
allow(games_relation).to receive(:includes).and_return([game1, game2])
```

### Expectation Syntax

```ruby
# Verify method called
expect(service).to receive(:method)

# Verify method called with args
expect(service).to receive(:method).with(arg1, arg2)

# Verify method NOT called
expect(service).not_to receive(:method)

# Verify method called N times
expect(service).to receive(:method).exactly(3).times
```

### Instance Doubles

```ruby
# For classes you control
let(:orchestrator) { instance_double(AiAssignment::OrchestratorService) }

before do
  allow(AiAssignment::OrchestratorService).to receive(:new).and_return(orchestrator)
  allow(orchestrator).to receive(:assign_open_games).and_return(result)
end
```

---

## Geocoder Testing

Models with address fields (Game, Official) require Geocoder stubbing.

### Setup and Teardown

```ruby
before do
  Geocoder.configure(lookup: :test)
  Geocoder::Lookup::Test.add_stub(
    "123 Main St, Boston, MA",
    [{
      "latitude" => 42.3601,
      "longitude" => -71.0589,
      "address" => "123 Main St, Boston, MA 02108",
      "city" => "Boston",
      "state" => "Massachusetts",
      "country" => "United States"
    }]
  )
end

after do
  Geocoder::Lookup::Test.reset
end
```

### Multiple Address Stubs

```ruby
before do
  Geocoder.configure(lookup: :test)

  # Game location
  Geocoder::Lookup::Test.add_stub(
    "Stadium A",
    [{ "latitude" => 40.7128, "longitude" => -74.0060 }]
  )

  # Official home address
  Geocoder::Lookup::Test.add_stub(
    "456 Elm St",
    [{ "latitude" => 40.7589, "longitude" => -73.9851 }]
  )
end

after do
  Geocoder::Lookup::Test.reset
end
```

### Testing Distance Calculations

```ruby
it "calculates distance correctly" do
  game = Game.create!(address: "Stadium A", ...)
  official = Official.create!(home_address: "456 Elm St", ...)

  distance = official.distance_to(game)
  expect(distance).to be_within(0.1).of(expected_distance)
end
```

---

## WebMock for HTTP Requests

All external API calls (primarily Ollama) use WebMock.

### Basic WebMock Stub

```ruby
before do
  stub_request(:post, "http://localhost:11434/api/generate")
    .to_return(
      status: 200,
      body: { response: "test response" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end
```

### Matching Request Body

```ruby
before do
  stub_request(:post, "http://localhost:11434/api/generate")
    .with(
      body: hash_including(
        model: "llama3.2",
        prompt: /assign officials/
      ),
      headers: { "Content-Type" => "application/json" }
    )
    .to_return(status: 200, body: mock_response.to_json)
end
```

### Multiple Response Scenarios

```ruby
# Success response
before do
  stub_request(:post, ollama_url)
    .with(body: hash_including(model: "llama3.2"))
    .to_return(
      status: 200,
      body: { response: "success" }.to_json
    )
end

# Error response (different context)
context "when API returns error" do
  before do
    stub_request(:post, ollama_url)
      .to_return(status: 500, body: "Internal Server Error")
  end

  it "raises an error" do
    expect { service.call }.to raise_error(/API error/)
  end
end
```

### Structured JSON Responses

```ruby
let(:mock_ollama_response) do
  {
    assignments: [
      { game_id: 1, official_id: 10, role: "referee" },
      { game_id: 1, official_id: 11, role: "hl" }
    ],
    reasoning: "Assigned based on distance and availability"
  }
end

before do
  stub_request(:post, ollama_url)
    .to_return(
      status: 200,
      body: mock_ollama_response.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end
```

---

## Model Testing Patterns

### Complete Model Test Structure

```ruby
require "rails_helper"

RSpec.describe ModelName, type: :model do
  # Geocoder setup if needed
  before do
    Geocoder.configure(lookup: :test)
    Geocoder::Lookup::Test.add_stub("address", [{ "latitude" => 40.7, "longitude" => -74 }])
  end

  after do
    Geocoder::Lookup::Test.reset
  end

  describe "validations" do
    # ...
  end

  describe "associations" do
    # ...
  end

  describe "enums" do
    # ...
  end

  describe "scopes" do
    # ...
  end

  describe "#instance_method" do
    # ...
  end

  describe ".class_method" do
    # ...
  end
end
```

### Validation Testing

```ruby
describe "validations" do
  let(:model) { Model.new(valid_attributes) }

  it "is valid with valid attributes" do
    expect(model).to be_valid
  end

  context "name" do
    it "is invalid without name" do
      model.name = nil
      expect(model).not_to be_valid
      expect(model.errors[:name]).to include("can't be blank")
    end

    it "is invalid with duplicate name" do
      Model.create!(name: "Test")
      duplicate = Model.new(name: "Test")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  context "email" do
    it "is invalid with incorrect format" do
      model.email = "invalid"
      expect(model).not_to be_valid
      expect(model.errors[:email]).to include("is invalid")
    end
  end
end
```

### Association Testing

```ruby
describe "associations" do
  it "belongs to game" do
    expect(Assignment.reflect_on_association(:game).macro).to eq(:belongs_to)
  end

  it "has many assignments" do
    expect(Official.reflect_on_association(:assignments).macro).to eq(:has_many)
  end

  it "has many games through assignments" do
    association = Official.reflect_on_association(:games)
    expect(association.macro).to eq(:has_many)
    expect(association.options[:through]).to eq(:assignments)
  end
end
```

### Enum Testing

```ruby
describe "enums" do
  it "defines status enum" do
    expect(Game.defined_enums["status"]).to eq({
      "scheduled" => 0,
      "in_progress" => 1,
      "completed" => 2,
      "cancelled" => 3
    })
  end

  it "allows setting status by symbol" do
    game = Game.new(status: :scheduled)
    expect(game.status).to eq("scheduled")
    expect(game.scheduled?).to be true
  end
end
```

### Database Constraint Testing

```ruby
context "database constraint" do
  it "prevents duplicate assignments at database level" do
    game = Game.create!(name: "Test")
    official = Official.create!(name: "John")

    Assignment.create!(game: game, official: official, role: :referee)
    duplicate = Assignment.new(game: game, official: official, role: :referee)

    expect {
      duplicate.save(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
```

### Scope Testing

```ruby
describe "scopes" do
  describe ".upcoming" do
    it "returns games in the future" do
      past_game = Game.create!(game_date: 1.day.ago, ...)
      future_game = Game.create!(game_date: 1.day.from_now, ...)

      expect(Game.upcoming).to include(future_game)
      expect(Game.upcoming).not_to include(past_game)
    end
  end
end
```

---

## Service Testing Patterns

### Class Method Services (Stateless)

```ruby
RSpec.describe ServiceName do
  describe ".class_method" do
    let(:input) { double("Input", id: 1, attribute: "value") }
    let(:dependency) { double("Dependency") }

    before do
      allow(DependencyClass).to receive(:find).and_return(dependency)
      allow(dependency).to receive(:process).and_return(result)
    end

    context "when input is valid" do
      it "returns expected result" do
        result = described_class.class_method(input)
        expect(result).to eq(expected)
      end
    end

    context "with empty input" do
      it "returns empty array" do
        result = described_class.class_method([])
        expect(result).to be_empty
      end
    end
  end
end
```

### Instance Method Services (Stateful)

```ruby
RSpec.describe ServiceName do
  let(:config) { "test-config" }
  let(:service) { described_class.new(config: config) }

  describe "#initialize" do
    it "initializes with default config" do
      expect { described_class.new }.not_to raise_error
    end

    it "initializes with custom config" do
      custom = described_class.new(config: "custom")
      expect(custom.instance_variable_get(:@config)).to eq("custom")
    end
  end

  describe "#perform" do
    let(:input) { "test input" }

    context "when successful" do
      it "returns result" do
        result = service.perform(input)
        expect(result).to eq(expected)
      end
    end

    context "when error occurs" do
      before do
        allow(dependency).to receive(:call).and_raise(StandardError)
      end

      it "handles error" do
        expect { service.perform(input) }.to raise_error(StandardError)
      end
    end
  end
end
```

---

## Controller Testing Patterns

### Index Action

```ruby
describe "GET #index" do
  it "returns successful response" do
    get :index
    expect(response).to be_successful
  end

  it "assigns @games" do
    games = Game.all
    get :index
    expect(assigns(:games)).to eq(games)
  end
end
```

### Create Action

```ruby
describe "POST #create" do
  context "with valid parameters" do
    let(:valid_attributes) { { name: "Test Game", game_date: 1.day.from_now } }

    it "creates a new game" do
      expect {
        post :create, params: { game: valid_attributes }
      }.to change(Game, :count).by(1)
    end

    it "redirects to created game" do
      post :create, params: { game: valid_attributes }
      expect(response).to redirect_to(Game.last)
    end
  end

  context "with invalid parameters" do
    let(:invalid_attributes) { { name: nil } }

    it "does not create game" do
      expect {
        post :create, params: { game: invalid_attributes }
      }.not_to change(Game, :count)
    end

    it "renders new template" do
      post :create, params: { game: invalid_attributes }
      expect(response).to render_template(:new)
    end
  end
end
```

---

## Job Testing Patterns

### Basic Job Test

```ruby
RSpec.describe JobName, type: :job do
  describe "#perform" do
    let(:param) { double("Model", id: 1) }
    let(:service) { instance_double(ServiceClass) }

    before do
      allow(ServiceClass).to receive(:new).and_return(service)
      allow(service).to receive(:perform).and_return(result)
    end

    it "calls service with correct parameters" do
      expect(service).to receive(:perform).with(param)
      described_class.perform_now(param)
    end

    context "when service fails" do
      before do
        allow(service).to receive(:perform).and_raise(StandardError)
      end

      it "handles error" do
        expect { described_class.perform_now(param) }.to raise_error(StandardError)
      end
    end
  end
end
```

---

## Common Matchers and Expectations

### Value Matchers

```ruby
expect(value).to eq(expected)              # Equality
expect(value).to be_truthy                 # Truthy value
expect(value).to be_falsy                  # Falsy value
expect(value).to be_nil                    # Nil check
expect(value).to be_present                # Rails present?
expect(value).to be_blank                  # Rails blank?
```

### Collection Matchers

```ruby
expect(array).to include(item)             # Contains item
expect(array).to be_empty                  # Empty check
expect(array.size).to eq(3)                # Size check
expect(hash).to have_key(:key)             # Hash key exists
expect(hash[:key]).to eq(value)            # Hash value
```

### Type Matchers

```ruby
expect(value).to be_a(String)              # Type check
expect(value).to be_an_instance_of(Game)   # Exact type
expect(value).to respond_to(:method)       # Responds to method
```

### Comparison Matchers

```ruby
expect(value).to be > 5                    # Greater than
expect(value).to be_between(1, 10)         # Range
expect(value).to be_within(0.1).of(5.0)    # Delta comparison
```

### Pattern Matchers

```ruby
expect(string).to match(/regex/)           # Regex match
expect(string).to start_with("prefix")     # String prefix
expect(string).to end_with("suffix")       # String suffix
```

### Change Matchers

```ruby
expect { action }.to change(Model, :count).by(1)       # Count change
expect { action }.to change(object, :attribute)        # Attribute change
expect { action }.not_to change(Model, :count)         # No change
```

### Raise Matchers

```ruby
expect { action }.to raise_error(ErrorClass)           # Specific error
expect { action }.to raise_error(/message/)            # Error message
expect { action }.not_to raise_error                   # No error
```

### Rails-Specific Matchers

```ruby
expect(model).to be_valid                   # Validation
expect(model).not_to be_valid              # Invalid
expect(model.errors[:field]).to include("message")  # Error message
expect(response).to be_successful          # HTTP 2xx
expect(response).to redirect_to(path)      # Redirect
expect(response).to render_template(:show) # Template
```

---

## Tips for Consistent Testing

1. **Use `described_class`** instead of hardcoded class name
2. **Keep contexts focused** on a single condition
3. **Use descriptive test names** that explain behavior
4. **Test both positive and negative cases**
5. **Include edge cases** (nil, empty, boundary values)
6. **Stub external dependencies** to keep tests fast
7. **Follow existing patterns** for consistency
8. **Update tests** when changing code behavior
9. **Run tests frequently** during development
10. **Keep tests readable** - future you will thank you

---

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/game_spec.rb

# Run specific test
bundle exec rspec spec/models/game_spec.rb:25

# Run with documentation format
bundle exec rspec --format documentation

# Run only failures
bundle exec rspec --only-failures
```

---

This reference guide reflects the actual testing patterns used in the Game Commissioner Rails application. Refer to existing spec files for real-world examples.
