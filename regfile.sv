module regfile (
    input  logic       clk,
    input  logic       reset,
    input  logic       reg_write,
    input  logic [1:0] rd_addr,
    input  logic [1:0] rs_addr,
    input  logic [7:0] write_data,
    output logic [7:0] rd_data,
    output logic [7:0] rs_data
);
    logic [7:0] regs [3:0];

    // Write & reset logic
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        regs[0] <= 8'b0;
        regs[1] <= 8'b0;
        regs[2] <= 8'b0;
        regs[3] <= 8'b0;
    end else if (reg_write) begin
        regs[rd_addr] <= write_data;
        $display("REGFILE: Write %0d to regs[%0d] at time %0t", write_data, rd_addr, $time);
    end
    $display("REGFILE: After clk/reset, [0]=%0d [1]=%0d [2]=%0d [3]=%0d", regs[0], regs[1], regs[2], regs[3]);
end

    // Read logic (combinational)
    assign rd_data = regs[rd_addr];
    assign rs_data = regs[rs_addr];
endmodule