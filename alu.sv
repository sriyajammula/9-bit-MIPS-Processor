// alu.sv
// Combinational 8-bit ALU with shift and carry flags

module alu (
  input  logic [7:0] A,
  input  logic [7:0] B,
  input  logic [3:0] opcode,
  output logic [7:0] result,
  output logic       shift_flag,
  output logic       carry_flag
);

  always_comb begin
    // default
    result     = 8'h00;
    shift_flag = 1'b0;
    carry_flag = 1'b0;

    case (opcode)
      4'b0000: {carry_flag, result} = A + B;      // ADD
      4'b0001: {carry_flag, result} = A - B;      // SUB
      4'b0010: result = A & B;                    // AND
      4'b0011: result = A | B;                    // OR
      4'b0100: begin                              // SHL
                  shift_flag = A[7];
                  result     = A << 1;
                end
      4'b0101: begin                              // SHR
                  shift_flag = A[0];
                  result     = A >> 1;
                end
      default: /* nop */;
    endcase
  end

endmodule
