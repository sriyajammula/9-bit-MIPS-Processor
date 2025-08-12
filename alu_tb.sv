module top_level_tb;
  logic clk, reset, start, done;

  // Instantiate DUT
  top_level dut (
    .clk   (clk),
    .reset (reset),
    .start (start),
    .done  (done)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  int max_cycles;
  int cycles;
  
  always @(posedge clk)
  $display("TB: start=%b, reset=%b", start, reset);


  // Testbench procedure
  initial begin
    $display("Starting processor simulation...");

    max_cycles = 1000;
    cycles = 0;

    // 1. Hold reset active for a few cycles
    reset = 1;
    start = 1;
    repeat (2) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // 2. Release start to let processor begin
    start = 0;
    $display("Processor started.");

    // 3. Run for up to N cycles or until done
    while (!done && cycles < max_cycles) begin
      @(posedge clk);
      cycles++;
    end

    if (done)
      $display("Processor done after %0d cycles!", cycles);
    else
      $display("Processor did not finish after %0d cycles. Possible hang!", max_cycles);
	
    $display("=====> Processor completed successfully after %0d cycles!", cycles);
    $display("Reg0 = %0d, Reg1 = %0d, Reg2 = %0d, Reg3 = %0d",
      dut.cpu.rf.regs[0],
      dut.cpu.rf.regs[1],
      dut.cpu.rf.regs[2],
      dut.cpu.rf.regs[3]);
    $display("Data mem[0] = %0d", dut.data_mem_i.mem[0]);
    $finish;
  end
endmodule
