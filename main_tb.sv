module tb;
  logic         clk;
  logic         reset;
  logic         start;
  logic         done;
  integer       cycle_count;

  top_level dut (
    .clk   (clk),
    .reset (reset),
    .start (start),
    .done  (done)
  );

  // Dump VCD
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb);
  end

  // 100MHz clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      cycle_count <= 0;
    else
      cycle_count <= cycle_count + 1;
  end

  // Proper reset/start sequence
  initial begin
    reset = 1; start = 0;
    @(posedge clk); // hold reset high for 2 clocks
    @(posedge clk);
    reset = 0; // release reset
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;
  end

  // Core state debug every cycle
  always_ff @(posedge clk) begin
    $display(
      "T=%0t | cycle=%0d | PC=%02h | instr=%09b | d_we=%b | d_addr=%02h | d_wdata=%02h | done=%b | R0=%0d | R1=%0d | R2=%0d | R3=%0d",
      $time, cycle_count,
      dut.pc, dut.instr_word,
      dut.d_we, dut.d_addr, dut.d_wdata,
      done,
      dut.cpu.rf.regs[0], dut.cpu.rf.regs[1], dut.cpu.rf.regs[2], dut.cpu.rf.regs[3]
    );
  end

  always_ff @(posedge clk) begin
    if (dut.d_we) begin
      $display("[%0t] STORE: mem[%0d] <= %02h", $time, dut.d_addr, dut.d_wdata);
    end
  end

  // Wait for done or timeout and print register/mem state
  initial begin
    int max_cycles = 1000;
    wait (done == 1 || cycle_count == max_cycles);

    $display("\n==== FINAL REGISTER STATE ====");
    $display("Reg0 = %0d, Reg1 = %0d, Reg2 = %0d, Reg3 = %0d",
      dut.cpu.rf.regs[0], dut.cpu.rf.regs[1], dut.cpu.rf.regs[2], dut.cpu.rf.regs[3]);

    $display("==== FINAL MEMORY DUMP ====");
    for (int i = 0; i < 8; i++)
      $display("Mem[%0d] = %02h", i, dut.data_mem_i.mem[i]);

    if (cycle_count == max_cycles)
      $error("FAIL: Testbench timed out!");
    else
      $display("PASS: Program completed. Done signal received.");
    $finish;
  end
  
endmodule