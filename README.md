# Game Commissioner - LLM Evaluator & Simulator

**Turn your Local LLM into a Sports Official Commissioner.**

This repository is a **simulation environment and evaluator** for Large Language Models (LLMs). It challenges LLMs to solve complex, constraint-based scheduling problems by acting as a "Game Commissioner" who must assign officials to sports games while respecting natural language rules, travel limits, and availability.

Use this to:
- **Evaluate LLM Reasoning**: Can the model balance "Only travels 20 miles" vs "Needs 3 assignments"?
- **Benchmark Performance**: Compare `llama3.2`, `mistral`, `gemma2`, and others on logic tasks.
- **Test Prompt Engineering**: Experiment with how you frame the problem to the AI.

## ⚡️ Quick Start

1.  **Prerequisites**:
    *   Ruby 3.3.4 (`rvm` recommended)
    *   PostgreSQL 12+
        *   *Linux (Ubuntu/Debian)*: `sudo apt-get install libpq-dev`
        *   *macOS*: `brew install postgresql`
    *   [Ollama](https://ollama.ai/) running locally

2.  **Setup**:
    ```bash
    # Install dependencies and setup database
    bin/setup
    
    # Pull a fast model for testing
    ollama pull llama3.2
    ```

3.  **Run**:
    ```bash
    # Starts Web Server, Tailwind, and Background Jobs in one command
    bin/dev
    ```

4.  **Simulate**:
    *   Open `http://localhost:3000`.
    *   Click **"Assign Open Games"**.
    *   Watch the AI process assignments in real-time!

---

## 🤖 Recommended Models & Configuration

This project uses [Ollama](https://ollama.ai/) to run local LLMs. While it defaults to `llama3.2`, you can swap in other models to test different capabilities.

### Recommended Models
Here are 5 recommended models ranging from lightweight to high-performance:

1.  **llama3.2** (3B) - *The Default.* Fast, efficient, and follows instructions well.
    ```bash
    ollama pull llama3.2
    ```
2.  **llama3.1** (8B) - *The Standard.* Excellent reasoning and consistency if the 3B model struggles.
    ```bash
    ollama pull llama3.1
    ```
3.  **gemma2** (9B) - *Strong Reasoner.* Google's open model, often outperforms on logic puzzles.
    ```bash
    ollama pull gemma2
    ```
4.  **mistral** (7B) - *Balanced.* A reliable general-purpose model with good JSON handling.
    ```bash
    ollama pull mistral
    ```
5.  **qwen2.5** (7B) - *High Performance.* Excellent structured output and benchmark scores.
    ```bash
    ollama pull qwen2.5
    ```
---

## 🎮 How to Customize the Simulation

**The Data is the Test.**
To change the scenario, you edit the seed data. This is how you create new "tests" for the LLM.

1.  **Edit `db/seeds.rb`**:
    This file contains the entire world state.
    *   **Officials**: Change their `rules` (e.g., "Won't work back-to-back days"), address, and roles.
    *   **Games**: Add games at specific locations/times to test travel and time conflicts.
    *   **Availability**: Add blackouts or specific availability windows.

2.  **Apply Changes**:
    After editing `db/seeds.rb`, run:
    ```bash
    rails db:reset
    ```
    *This drops the database, recreates it, and re-runs your updated seed file.*

3.  **Re-Run Simulation**:
    Go back to `http://localhost:3000` and click "Assign Open Games" to see how the LLM handles your new scenario.

---

## 🏗 Architecture

*   **Rails 8.1**: Web framework & DB management.
*   **Solid Queue**: Background job processing (manages the AI agents).
*   **Hotwire/Turbo**: Real-time UI updates as assignments happen.
*   **Ollama**: Local inference engine.

**Built for testing. Hack it, break it, improve it.**
