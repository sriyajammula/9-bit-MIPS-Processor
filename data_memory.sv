module data_memory (
  input  logic       clk,
  input  logic       reset,    // active-high reset
  input  logic       we,
  input  logic [7:0] addr,
  input  logic [7:0] write_data,
  output logic [7:0] read_data
);
  logic [7:0] mem [0:255];

  // Synchronous write, async read
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      integer i;
      for (i = 0; i < 256; i = i + 1)
        mem[i] <= 8'h00;
      $display("DATA_MEM: RESET all memory to 0");
    end else if (we) begin
      mem[addr] <= write_data;
      $display("DATA_MEM: Write %0h to mem[%0h] at time %0t", write_data, addr, $time);
    end
  end

  // Asynchronous read: always up-to-date
  assign read_data = mem[addr];

endmodule