# Game Commissioner - LLM Scheduling Test Simulation

## Purpose

**This is a simulation environment designed to test and evaluate Large Language Models (LLMs) on complex scheduling tasks.**

This application serves as a testbed for assessing how well different LLM models can handle real-world constraint-based scheduling problems. It simulates a sports official assignment system where an AI must:

- **Understand natural language rules** ("Only travels 20 miles", "Won't work back-to-back days")
- **Evaluate multiple constraints** (distance, availability, role compatibility, conflicts)
- **Make intelligent decisions** based on complex, sometimes competing criteria
- **Score and rank candidates** for optimal assignment matching

Use this simulation to:
- Compare different LLM models (llama, mistral, qwen, etc.) on scheduling accuracy
- Test prompt engineering strategies for constraint satisfaction
- Evaluate how well models handle natural language business rules
- Benchmark LLM performance on real-world assignment problems

## How It Works

The simulation provides a sports scheduling scenario with:
- **6 Officials** - Each with unique availability, travel limits, and natural language rules
- **6 Games** - Requiring 5 distinct roles to be filled (Referee, HL, LJ, BJ, U/C)
- **30 Total Positions** - To be assigned optimally by the LLM

The LLM must evaluate each official against the game requirements and their personal rules, then assign the best matches while respecting all constraints.

---

## Prerequisites

Before running the simulation, ensure you have:

- **Ruby 3.3.4** - Use RVM, rbenv, or your preferred Ruby version manager
- **PostgreSQL** - Database server (v12 or higher recommended)
- **Ollama** - Local LLM runtime ([Download here](https://ollama.ai/))
- **macOS, Linux, or WSL2** - Windows users should use WSL2

---

## Step-by-Step Setup Instructions

### Step 1: Install Ollama and Pull a Model

Ollama is required to run the LLM that evaluates scheduling assignments.

#### On macOS:
```bash
# Download and install from https://ollama.ai/
# Or use Homebrew:
brew install ollama
```

#### On Linux:
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

#### Pull a model for testing:
```bash
# Start with llama3.2 (small, fast, good for testing)
ollama pull llama3.2

# Or try other models:
# ollama pull llama3.1        # Larger, more capable
# ollama pull mistral         # Alternative model
# ollama pull qwen2.5         # Another option for comparison
```

#### Verify Ollama is running:
```bash
# Check if Ollama is responding
curl http://localhost:11434/api/tags

# You should see a JSON response listing your models
```

---

### Step 2: Install Ruby and Dependencies

#### Using RVM (recommended for this project):
```bash
# The project uses Ruby 3.3.4
rvm use 3.3.4

# If not installed, RVM will prompt you to install it
# rvm install 3.3.4
```

#### Install Ruby gems:
```bash
# Navigate to the project directory
cd /path/to/game_commish

# Install all dependencies
bundle install
```

If you encounter issues, you may need to install bundler first:
```bash
gem install bundler
bundle install
```

---

### Step 3: Setup PostgreSQL Database

#### Ensure PostgreSQL is running:

**macOS (Homebrew):**
```bash
brew services start postgresql
```

**Linux:**
```bash
sudo systemctl start postgresql
```

#### Create and setup the database:
```bash
# Create the database
rails db:create

# Run migrations to create tables
rails db:migrate

# Load seed data (6 officials, 6 games, rules)
rails db:seed
```

**Expected output from `rails db:seed`:**
```
Clearing existing data...
Creating officials...
  Created official: John Smith
  Created official: Sarah Johnson
  Created official: Mike Williams
  Created official: Emily Davis
  Created official: Robert Brown
  Created official: Jennifer Wilson

Creating games...
  Created game: Lincoln vs Roosevelt on November 23 at 07:00 PM
  Created game: Jefferson vs Madison on November 25 at 06:30 PM
  ...

Seed data created successfully!
6 officials created
6 games created
15 rules created
18 official roles created
```

---

### Step 4: Configure the Model (Optional)

By default, the simulation uses `llama3.2` on `http://localhost:11434`.

To use a different model, set environment variables:

```bash
# Create a .env file in the project root
echo "OLLAMA_MODEL=mistral" > .env
echo "OLLAMA_URL=http://localhost:11434" >> .env
```

Or export them directly:
```bash
export OLLAMA_MODEL=llama3.1
export OLLAMA_URL=http://localhost:11434
```

---

### Step 5: Start the Application

You need **three terminal windows/tabs** to run the full simulation:

#### Terminal 1 - Rails Server:
```bash
cd /path/to/game_commish

# Start Rails server and Tailwind CSS
bin/dev
```

Expected output:
```
web: bin/rails server
css: bin/rails tailwindcss:watch
...
Listening on http://127.0.0.1:3000
```

#### Terminal 2 - Background Jobs:
```bash
cd /path/to/game_commish

# Start Solid Queue for AI assignment jobs
bin/jobs
```

Expected output:
```
Starting Solid Queue...
```

#### Terminal 3 - Ollama (if not already running):
```bash
# Ollama usually runs automatically after installation
# If needed, start it manually:
ollama serve
```

---

### Step 6: Access the Simulation

1. **Open your browser** and navigate to:
   ```
   http://localhost:3000
   ```

2. You should see the **Game Commissioner** interface with:
   - Navigation bar with "Games", "Officials", and "Assign Open Games" button
   - List of 6 upcoming games
   - Each game showing 5 empty role slots (REFEREE, HL, LJ, BJ, UC)

---

## Running the Simulation

### Option 1: Manual Testing (Baseline)

Test manual assignment to establish a baseline:

1. Go to the **Games** page (home page)
2. For each game, click a dropdown under a role (e.g., REFEREE)
3. Select an official from the list
4. The assignment saves immediately
5. Note which officials can/cannot be assigned based on their roles

**Use this to understand the constraints before testing AI assignments.**

---

### Option 2: AI-Powered Scheduling Test

This is the primary simulation mode for testing LLM performance.

#### Running the Test:

1. **Reset the database** (to clear any manual assignments):
   ```bash
   rails db:reset
   ```

2. **Start the simulation**:
   - Click the **"Assign Open Games"** button in the navigation
   - Confirm the prompt

3. **What happens:**
   - Background job starts processing all 30 open positions
   - For each position, the LLM evaluates all eligible officials
   - AI scores each candidate (0-100) based on rules and constraints
   - Best match (score ≥ 60) is assigned
   - Results update in real-time via WebSockets

4. **Monitor the logs** in Terminal 1:
   ```
   AI Assignment completed: {:total_games=>6, :assignments_made=>25, :assignments_failed=>5, :errors=>[...]}
   ```

5. **Review results:**
   - Games page updates automatically
   - Green assignments indicate successful matches
   - Empty slots indicate no suitable official found

---

## Testing Different Models

To compare how different LLM models perform on scheduling:

### Test with llama3.2 (fast, baseline):
```bash
export OLLAMA_MODEL=llama3.2
rails db:reset
# Click "Assign Open Games"
# Record: assignments made, failures, time taken
```

### Test with llama3.1 (larger, potentially more accurate):
```bash
ollama pull llama3.1
export OLLAMA_MODEL=llama3.1
rails db:reset
# Click "Assign Open Games"
# Compare results with llama3.2
```

### Test with mistral:
```bash
ollama pull mistral
export OLLAMA_MODEL=mistral
rails db:reset
# Click "Assign Open Games"
# Compare results
```

---

## Understanding the Test Data

### Officials and Their Rules:

1. **John Smith** - Referee, HL
   - "Only travels within 20 miles of home"
   - "Doesn't work back to back days"
   - "Won't work at Jefferson High School"

2. **Sarah Johnson** - Referee, UC, BJ
   - "Maximum 30 miles from home"
   - "Prefers evening games after 6 PM"
   - "Available Friday through Sunday only"

3. **Mike Williams** - LJ, BJ, UC
   - "Won't travel more than 25 miles"
   - "Can't work on Wednesdays"

4. **Emily Davis** - Referee, HL, LJ
   - "Flexible with travel up to 35 miles"
   - "No games at Lincoln High School"

5. **Robert Brown** - UC, BJ
   - "Only works within 15 miles"
   - "No consecutive day assignments"

6. **Jennifer Wilson** - All roles
   - "Can fill any role"
   - "Willing to travel up to 40 miles"
   - "Prefers not to work at Madison High School"

### Games (Portland Metro Area):
- Lincoln vs Roosevelt (3 days out)
- Jefferson vs Madison (5 days out)
- Grant vs Cleveland (7 days out)
- Wilson vs Benson (10 days out)
- Franklin vs Marshall (12 days out)
- Sunset vs Beaverton (14 days out)

**Each game is at a different location with real GPS coordinates for distance calculations.**

---

## Evaluating Model Performance

After running the simulation, evaluate the LLM on:

### Quantitative Metrics:
- **Success Rate**: Assignments made / Total positions
- **Rule Compliance**: Check if assignments violate stated rules
- **Distance Compliance**: Verify travel distances respected
- **Conflict Detection**: Check for back-to-back games

### Qualitative Assessment:
- **Reasoning Quality**: Read the AI's reasoning in the logs
- **Edge Case Handling**: How does it handle tight constraints?
- **Preference Interpretation**: Does it understand "prefers" vs "won't"?

### Access Detailed Results:
```bash
# Open Rails console to inspect assignments
rails console

# Check all assignments
Assignment.includes(:game, :official).each do |a|
  puts "#{a.game.name} - #{a.role.upcase}: #{a.official.name}"
end

# Check for rule violations
Official.includes(:rules, :assignments).find_each do |official|
  puts "\n#{official.name}:"
  official.rules.each { |r| puts "  - #{r.rule_text}" }
  puts "  Assigned to: #{official.games.map(&:name).join(', ')}"
end
```

## Troubleshooting

### Issue: "Connection refused" when clicking "Assign Open Games"

**Problem**: Ollama is not running or not accessible.

**Solutions**:
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# If not running, start it:
ollama serve

# Verify your model is available:
ollama list
```

---

### Issue: No assignments made (0/30 assigned)

**Possible causes**:

1. **Officials don't have roles assigned**:
   ```bash
   rails console
   # Check role counts:
   OfficialRole.count
   # Should be 18 after seeding
   ```

2. **Model not responding**:
   - Check Terminal 1 (Rails logs) for errors
   - Try a smaller/faster model: `export OLLAMA_MODEL=llama3.2`

3. **All candidates filtered out**:
   - Check if distance limits are too restrictive
   - Review rules in the Officials page

---

### Issue: Rails server won't start

**Common fixes**:
```bash
# Port 3000 already in use:
lsof -ti:3000 | xargs kill -9

# Missing gems:
bundle install

# Database connection error:
rails db:create
rails db:migrate
```

---

### Issue: Background jobs not processing

**Check**:
```bash
# Ensure bin/jobs is running in Terminal 2
bin/jobs

# Check job queue in Rails console:
rails console
> SolidQueue::Job.count
```

---

### Issue: Assignments violate rules

This might indicate the LLM is not correctly interpreting rules. Document and compare across models:

```bash
# Inspect what was assigned:
rails console
Official.find_by(name: "John Smith").assignments.each do |a|
  game = a.game
  distance = calculate_distance(...)  # Check if distance rule violated
  puts "#{game.name} at #{game.location} - Distance: #{distance} miles"
end
```

---

## Advanced Configuration

### Modifying the Prompt

The LLM evaluation prompt is in `app/services/ollama_service.rb:52` (`build_evaluation_prompt` method).

Edit this to test different prompt engineering strategies:

```ruby
def build_evaluation_prompt(official:, game:, role:)
  # Modify the prompt template here
  # Test different instruction formats
  # Adjust temperature in generate() method
end
```

### Adjusting the Scoring Threshold

Default threshold is 60/100 in `app/services/ai_assignment_service.rb:85`.

Lower it to see more assignments (potentially lower quality):
```ruby
if best_match[:score] >= 40  # Changed from 60
```

### Changing Temperature

In `app/services/ollama_service.rb:60`:
```ruby
options: {
  temperature: 0.1,  # Lower = more deterministic
  num_predict: 500
}
```

---

## Technical Architecture

### Key Components:

```
┌─────────────────────────────────────────────────┐
│ Browser (Turbo Streams WebSocket)             │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ AssignmentsController                          │
│ ├─ create (manual assignment)                  │
│ └─ assign_open_games → Enqueue Job            │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ AssignOpenGamesJob (Solid Queue)               │
│ └─ Calls AiAssignmentService                   │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ AiAssignmentService                            │
│ ├─ Find candidate officials                    │
│ ├─ Filter by distance/availability             │
│ └─ For each: Call OllamaService                │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ OllamaService                                  │
│ ├─ Build evaluation prompt                     │
│ ├─ Send to Ollama LLM                         │
│ ├─ Parse SCORE and REASONING                   │
│ └─ Return to AiAssignmentService               │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ Ollama (Local LLM)                             │
│ ├─ llama3.2 / mistral / etc.                  │
│ └─ Returns natural language response           │
└─────────────────────────────────────────────────┘
```

---

## Research & Testing Ideas

### Experiment 1: Prompt Engineering
- Test different instruction formats (few-shot examples, chain-of-thought)
- Compare scoring consistency across runs
- Try structured output formats (JSON instead of text parsing)

### Experiment 2: Model Comparison
- Benchmark speed: llama3.2 vs llama3.1 vs mistral
- Compare accuracy on rule interpretation
- Test smaller models (1B params) vs larger (7B+)

### Experiment 3: Constraint Complexity
- Add more officials with conflicting rules
- Add hard constraints (licensing, certifications)
- Test with 50+ games to see scaling behavior

### Experiment 4: Hybrid Approaches
- Use LLM for scoring, rule-based for filtering
- Try multiple LLM calls per assignment (verification step)
- Implement voting across different models

---

## Support & Contribution

This is a simulation/testbed for research. Feel free to:
- Modify the test data in `db/seeds.rb`
- Adjust the AI prompts in `app/services/ollama_service.rb`
- Add new constraints or rules to test
- Test with different Ollama models
- Report interesting findings or model behaviors

---

## Tech Stack Reference

- **Framework**: Ruby on Rails 8.1
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL
- **Background Jobs**: Solid Queue (Rails 8)
- **AI Runtime**: Ollama
- **Distance Calculations**: Haversine formula (built-in)

---


**Built for testing LLM scheduling capabilities. Modify and experiment freely!**
