require "spec"
require "../src/crystalline/requires"
require "../src/crystalline/main"
require "../src/crystalline/utils"
require "../src/crystalline/analysis/analysis"

describe "Crystalline::SignatureHelp" do
  describe "basic functionality" do
    it "has public method signature_help_at_cursor" do
      Crystalline::Analysis.responds_to?(:signature_help_at_cursor).should be_true
    end

    it "has public method find_call_node" do
      Crystalline::Analysis.responds_to?(:find_call_node).should be_true
    end

    it "has public method find_method_definition" do
      Crystalline::Analysis.responds_to?(:find_method_definition).should be_true
    end

    it "has public method calculate_active_parameter" do
      Crystalline::Analysis.responds_to?(:calculate_active_parameter).should be_true
    end

    it "has public method build_signature_help" do
      Crystalline::Analysis.responds_to?(:build_signature_help).should be_true
    end
  end

  describe "build_signature_help structure" do
    it "returns proper LSP::SignatureHelp structure" do
      def_node = Crystal::Def.new("test_method", [
        Crystal::Arg.new("param1", restriction: Crystal::Path.new("String")),
        Crystal::Arg.new("param2", restriction: Crystal::Path.new("Int32")),
      ])

      result = Crystalline::Analysis.build_signature_help(def_node, 0)

      result.should be_a(LSP::SignatureHelp)
      result.signatures.size.should eq(1)
      result.active_signature.should eq(0)
      result.active_parameter.should eq(0)
      result.signatures[0].should be_a(LSP::SignatureInformation)
      result.signatures[0].parameters.should_not be_nil
      result.signatures[0].parameters.not_nil!.size.should eq(2)
    end

    it "handles method with no parameters" do
      def_node = Crystal::Def.new("no_params", [] of Crystal::Arg)

      result = Crystalline::Analysis.build_signature_help(def_node, 0)

      result.should be_a(LSP::SignatureHelp)
      result.signatures.size.should eq(1)
      result.signatures[0].parameters.should_not be_nil
      result.signatures[0].parameters.not_nil!.size.should eq(0)
    end

    it "formats parameter labels correctly" do
      def_node = Crystal::Def.new("formatted_method", [
        Crystal::Arg.new("name", restriction: Crystal::Path.new("String")),
      ])

      result = Crystalline::Analysis.build_signature_help(def_node, 0)

      result.signatures[0].parameters.not_nil![0].label.should contain("name")
      result.signatures[0].parameters.not_nil![0].label.should contain("String")
    end
  end

  describe "calculate_active_parameter" do
    it "returns 0 when no arguments are present" do
      call_node = Crystal::Call.new(nil, "test")
      location = Crystal::Location.new("test.cr", 1, 10)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, location)

      result.should eq(0)
    end

    it "returns 0 when cursor is before first argument" do
      arg1 = Crystal::StringLiteral.new("first")
      arg1.location = Crystal::Location.new("test.cr", 1, 10)
      arg1.end_location = Crystal::Location.new("test.cr", 1, 17)

      call_node = Crystal::Call.new(nil, "test", [arg1] of Crystal::ASTNode)
      cursor_location = Crystal::Location.new("test.cr", 1, 5)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, cursor_location)

      result.should eq(0)
    end

    it "returns 0 when cursor is inside first argument" do
      arg1 = Crystal::StringLiteral.new("first")
      arg1.location = Crystal::Location.new("test.cr", 1, 10)
      arg1.end_location = Crystal::Location.new("test.cr", 1, 17)

      call_node = Crystal::Call.new(nil, "test", [arg1] of Crystal::ASTNode)
      cursor_location = Crystal::Location.new("test.cr", 1, 12)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, cursor_location)

      result.should eq(0)
    end

    it "returns 1 when cursor is after first argument (before second)" do
      arg1 = Crystal::StringLiteral.new("first")
      arg1.location = Crystal::Location.new("test.cr", 1, 10)
      arg1.end_location = Crystal::Location.new("test.cr", 1, 17)

      call_node = Crystal::Call.new(nil, "test", [arg1] of Crystal::ASTNode)
      cursor_location = Crystal::Location.new("test.cr", 1, 20)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, cursor_location)

      result.should eq(1)
    end

    it "returns 1 when cursor is before second argument" do
      arg1 = Crystal::StringLiteral.new("first")
      arg1.location = Crystal::Location.new("test.cr", 1, 10)
      arg1.end_location = Crystal::Location.new("test.cr", 1, 17)

      arg2 = Crystal::NumberLiteral.new(42)
      arg2.location = Crystal::Location.new("test.cr", 1, 20)
      arg2.end_location = Crystal::Location.new("test.cr", 1, 22)

      call_node = Crystal::Call.new(nil, "test", [arg1, arg2] of Crystal::ASTNode)
      cursor_location = Crystal::Location.new("test.cr", 1, 19)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, cursor_location)

      result.should eq(1)
    end

    it "returns 1 when cursor is inside second argument" do
      arg1 = Crystal::StringLiteral.new("first")
      arg1.location = Crystal::Location.new("test.cr", 1, 10)
      arg1.end_location = Crystal::Location.new("test.cr", 1, 17)

      arg2 = Crystal::NumberLiteral.new(42)
      arg2.location = Crystal::Location.new("test.cr", 1, 20)
      arg2.end_location = Crystal::Location.new("test.cr", 1, 22)

      call_node = Crystal::Call.new(nil, "test", [arg1, arg2] of Crystal::ASTNode)
      cursor_location = Crystal::Location.new("test.cr", 1, 21)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, cursor_location)

      result.should eq(1)
    end

    it "returns args.size when cursor is after all arguments" do
      arg1 = Crystal::StringLiteral.new("first")
      arg1.location = Crystal::Location.new("test.cr", 1, 10)
      arg1.end_location = Crystal::Location.new("test.cr", 1, 17)

      arg2 = Crystal::NumberLiteral.new(42)
      arg2.location = Crystal::Location.new("test.cr", 1, 20)
      arg2.end_location = Crystal::Location.new("test.cr", 1, 22)

      call_node = Crystal::Call.new(nil, "test", [arg1, arg2] of Crystal::ASTNode)
      cursor_location = Crystal::Location.new("test.cr", 1, 25)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, cursor_location)

      result.should eq(2)
    end

    it "handles arguments without end_location" do
      arg1 = Crystal::StringLiteral.new("first")
      arg1.location = Crystal::Location.new("test.cr", 1, 10)

      call_node = Crystal::Call.new(nil, "test", [arg1] of Crystal::ASTNode)
      cursor_location = Crystal::Location.new("test.cr", 1, 20)

      result = Crystalline::Analysis.calculate_active_parameter(call_node, cursor_location)

      result.should eq(1)
    end
  end
end
