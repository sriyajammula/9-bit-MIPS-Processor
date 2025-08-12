module reg_file #(parameter W=8, D=4)( // W = size of register, 2^d is number of registers
    input         CLK,
	              RegWrite,
					  checkand,
    input  [ D-1:0] R1,
                    R2,
                    writeReg,
    input  [ W-1:0] writeValue, cmpVal,
	 input  [5:0] xorOp, 
	 input  [   1:0] immediate, 
    output logic [W-1:0] val1,
    output logic [W-1:0] val2,
	 output logic [ W-1:0] out_writeValue
    );

// 32 bits wide [31:0] and 64 registers deep [0:63] or just [64]	 
reg [7:0] registers_arr[0:9];
// combinational reads
assign      val1 = registers_arr[R1];
always_comb val2 = (xorOp == 'b010110) ? registers_arr[6] : (checkand==1) ? registers_arr[0] : registers_arr[R2];

//always_ff @ (checkand)
	


// sequential (clocked) writes
always_ff @ (posedge CLK)
  if (RegWrite) begin
    if(xorOp == 'b010110) begin
		registers_arr[6] <= writeValue;
	 end
    else if(cmpVal == 1) begin
		//$display("IN REG FILE; writeValue = %d", $signed(writeValue));
		registers_arr[8] <= $signed(writeValue);
		out_writeValue <= $signed(writeValue);
	 end
	 else if (immediate == 2) begin
		//$display("DUMPING into r0! %d", writeValue);
		registers_arr[0] <= writeValue;
	 end
	 else begin
		registers_arr[writeReg] <= writeValue;	
	 end
	end 
endmodule
