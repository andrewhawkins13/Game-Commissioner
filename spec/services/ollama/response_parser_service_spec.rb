require "rails_helper"

RSpec.describe Ollama::ResponseParserService do
  let(:model) { "llama3.2" }
  let(:parser) { described_class.new(model: model) }

  describe "#parse_evaluation" do
    context "with valid JSON response" do
      let(:response) { '{"score": 85, "reasoning": "Good match for this position"}' }

      it "parses the response correctly" do
        result = parser.parse_evaluation(response)

        expect(result[:score]).to eq(85)
        expect(result[:reasoning]).to eq("Good match for this position")
        expect(result[:error]).to be false
      end
    end

    context "with JSON wrapped in markdown code blocks" do
      let(:response) do
        <<~RESPONSE
          ```json
          {"score": 92, "reasoning": "Excellent match"}
          ```
        RESPONSE
      end

      it "extracts and parses the JSON" do
        result = parser.parse_evaluation(response)

        expect(result[:score]).to eq(92)
        expect(result[:reasoning]).to eq("Excellent match")
        expect(result[:error]).to be false
      end
    end

    context "with JSON embedded in extra text" do
      let(:response) do
        'Here is my evaluation: {"score": 75, "reasoning": "Decent match"} That is my analysis.'
      end

      it "extracts and parses the JSON" do
        result = parser.parse_evaluation(response)

        expect(result[:score]).to eq(75)
        expect(result[:reasoning]).to eq("Decent match")
        expect(result[:error]).to be false
      end
    end

    context "with text format (fallback)" do
      let(:response) do
        <<~RESPONSE
          SCORE: 88
          REASONING: This official has great experience with this type of game.
        RESPONSE
      end

      it "parses using regex fallback" do
        result = parser.parse_evaluation(response)

        expect(result[:score]).to eq(88)
        expect(result[:reasoning]).to eq("This official has great experience with this type of game.")
        expect(result[:error]).to be false
      end
    end

    context "with score out of range" do
      it "clamps score to 0-100 range (too high)" do
        response = '{"score": 150, "reasoning": "Too high"}'
        result = parser.parse_evaluation(response)

        expect(result[:score]).to eq(100)
      end

      it "clamps score to 0-100 range (negative)" do
        response = '{"score": -10, "reasoning": "Negative"}'
        result = parser.parse_evaluation(response)

        expect(result[:score]).to eq(0)
      end
    end

    context "with unparseable response" do
      let(:response) { "This is completely unparseable text without any structure" }

      it "returns zero score and full text as reasoning" do
        result = parser.parse_evaluation(response)

        expect(result[:score]).to eq(0)
        expect(result[:reasoning]).to eq(response.strip)
        expect(result[:error]).to be false
      end
    end
  end

  describe "#parse_assignment" do
    let(:game1) { double("Game", id: 1) }
    let(:game2) { double("Game", id: 2) }
    let(:official1) { double("Official", id: 10) }
    let(:official2) { double("Official", id: 20) }
    let(:games) { [game1, game2] }
    let(:officials) { [official1, official2] }

    context "with valid JSON response" do
      let(:response) do
        {
          assignments: [
            { game_id: 1, role: "referee", official_id: 10, score: 90, reasoning: "Perfect match" },
            { game_id: 2, role: "umpire", official_id: 20, score: 85, reasoning: "Good fit" }
          ],
          summary: "Assigned both games"
        }.to_json
      end

      it "parses all assignments correctly" do
        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result.length).to eq(2)

        first = result[0]
        expect(first[:game]).to eq(game1)
        expect(first[:official]).to eq(official1)
        expect(first[:role]).to eq("referee")
        expect(first[:score]).to eq(90)
        expect(first[:reasoning]).to eq("Perfect match")

        second = result[1]
        expect(second[:game]).to eq(game2)
        expect(second[:official]).to eq(official2)
        expect(second[:role]).to eq("umpire")
        expect(second[:score]).to eq(85)
        expect(second[:reasoning]).to eq("Good fit")
      end
    end

    context "with JSON wrapped in markdown" do
      let(:response) do
        <<~RESPONSE
          ```json
          {
            "assignments": [
              {"game_id": 1, "role": "referee", "official_id": 10, "score": 88, "reasoning": "Great choice"}
            ],
            "summary": "Done"
          }
          ```
        RESPONSE
      end

      it "extracts and parses the JSON" do
        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result.length).to eq(1)
        expect(result[0][:game]).to eq(game1)
        expect(result[0][:score]).to eq(88)
      end
    end

    context "with text format (fallback)" do
      let(:response) do
        <<~RESPONSE
          ASSIGNMENT: game_1 - referee - official_10
          SCORE: 92
          REASONING: Excellent experience

          ASSIGNMENT: game_2 - umpire - official_20
          SCORE: 80
          REASONING: Solid choice

          SUMMARY: All positions filled
        RESPONSE
      end

      it "parses using regex fallback" do
        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result.length).to eq(2)
        expect(result[0][:game]).to eq(game1)
        expect(result[0][:role]).to eq("referee")
        expect(result[1][:game]).to eq(game2)
        expect(result[1][:role]).to eq("umpire")
      end
    end

    context "with invalid game ID" do
      let(:response) do
        {
          assignments: [
            { game_id: 999, role: "referee", official_id: 10, score: 90, reasoning: "Invalid game" }
          ],
          summary: "Assignment attempted"
        }.to_json
      end

      it "skips invalid assignments and logs warning" do
        expect(Rails.logger).to receive(:warn).with(/Assignment Parse Failed.*game not found/)
        expect(Rails.logger).to receive(:warn).with(/Available game IDs/)
        expect(Rails.logger).to receive(:warn).with(/Available official IDs/)
        expect(Rails.logger).to receive(:warn).with(/Failed to parse 1 assignment/)

        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result).to be_empty
      end
    end

    context "with invalid official ID" do
      let(:response) do
        {
          assignments: [
            { game_id: 1, role: "referee", official_id: 999, score: 90, reasoning: "Invalid official" }
          ],
          summary: "Assignment attempted"
        }.to_json
      end

      it "skips invalid assignments and logs warning" do
        expect(Rails.logger).to receive(:warn).with(/Assignment Parse Failed.*official not found/)
        expect(Rails.logger).to receive(:warn).with(/Available game IDs/)
        expect(Rails.logger).to receive(:warn).with(/Available official IDs/)
        expect(Rails.logger).to receive(:warn).with(/Failed to parse 1 assignment/)

        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result).to be_empty
      end
    end

    context "with role in uppercase" do
      let(:response) do
        {
          assignments: [
            { game_id: 1, role: "REFEREE", official_id: 10, score: 90, reasoning: "Test" }
          ],
          summary: "Done"
        }.to_json
      end

      it "converts role to lowercase" do
        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result[0][:role]).to eq("referee")
      end
    end

    context "with score out of range" do
      let(:response) do
        {
          assignments: [
            { game_id: 1, role: "referee", official_id: 10, score: 150, reasoning: "Too high" }
          ],
          summary: "Done"
        }.to_json
      end

      it "clamps score to 100" do
        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result[0][:score]).to eq(100)
      end
    end

    context "with empty response" do
      let(:response) { '{"assignments": [], "summary": "No assignments"}' }

      it "returns empty array" do
        result = parser.parse_assignment(response, games: games, officials: officials)

        expect(result).to be_empty
      end
    end
  end
end
