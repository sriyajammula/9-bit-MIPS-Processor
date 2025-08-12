// top_level.sv
// Fetch stage with core_instr freeze in FETCH (state 2'b00)
module top_level (
  input  logic       clk,
  input  logic       reset,
  input  logic       start,
  output logic       done
);
  logic [7:0]    pc;
  logic [8:0]    instr_word;
  logic          ext_pending;
  logic [7:0]    ext_data;
  logic          ext_valid;
  logic [8:0]    core_instr;

  logic [7:0]    d_addr, d_wdata, d_rdata;
  logic          d_we;
  logic          pc_load;
  logic [7:0]    pc_target;
  logic [1:0]    cpu_state;

  // data RAM
  data_memory data_mem_i (
    .clk        (clk),
    .reset      (reset),
    .we         (d_we),
    .addr       (d_addr),
    .write_data (d_wdata),
    .read_data  (d_rdata)
  );

  // instruction ROM
  instruction_memory im(
    .addr  (pc),
    .instr (instr_word)
  );

  // EXT prefix detection
  always_ff @(posedge clk or posedge reset) begin
    if (reset) ext_pending <= 1'b0;
    else       ext_pending <= (instr_word[8:5] == 4'b1110);
  end

  always_ff @(posedge clk) begin
    ext_valid <= ext_pending;
    if (ext_pending)
      ext_data <= instr_word[7:0];
  end

  // core instantiation
  my_processor cpu(
    .clk        (clk),
    .reset      (reset),
    .start      (start),
    .instr      (core_instr),
    .ext_valid  (ext_valid),
    .ext_data   (ext_data),
    .d_in       (d_rdata),
    .pc         (pc),
    .d_addr     (d_addr),
    .d_out      (d_wdata),
    .we         (d_we),
    .done       (done),
    .pc_load    (pc_load),
    .pc_target  (pc_target),
    .state_out  (cpu_state)
  );

  // fetch + freeze core_instr
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      pc         <= 8'd0;
      core_instr <= 9'b0;
    end else if (!start) begin
      // Only latch new instruction in FETCH state (2'b00)
      if (cpu_state == 2'b00) begin
        core_instr <= instr_word;
        // Advance PC (skipping EXT bytes)
        if (!ext_pending) begin
          if (pc_load)
            pc <= pc_target;
          else
            pc <= pc + 1;
        end else begin
          // If this was an EXT prefix, we consume it but do not overwrite core_instr
          pc <= pc + 1;
        end
      end
      // In non-FETCH, we hold both pc and core_instr stable
    end
  end

  always_ff @(posedge clk) begin
    $display("Time=%0t | PC=%0d | instr_word=%b | core_instr=%b | cpu_state=%b | done=%b", 
             $time, pc, instr_word, core_instr, cpu_state, done);
  end
endmodule