// instruction_memory.sv
module instruction_memory (
  input  logic [7:0] addr,
  output logic [8:0] instr
);
  logic [8:0] rom [0:255] = '{default:9'b000000000};

  initial begin
    $readmemb("program.bin", rom);
    for (int i = 0; i < 8; i++) begin
      $display("ROM[%0d] = %09b", i, rom[i]);
    end
  end

  assign instr = rom[addr];
endmodule
