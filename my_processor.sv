module my_processor (
    input  logic        clk,
    input  logic        reset,      // active-high reset
    input  logic        start,      // stall fetch when high
    input  logic [8:0]  instr,      // fetched 9-bit instruction
    input  logic        ext_valid,  // EXT immediate valid
    input  logic [7:0]  ext_data,   // EXT low-8 immediate
    input  logic [7:0]  d_in,       // data-memory read port
    input  logic [7:0]  pc,         // current PC value

    // data-memory interface
    output logic [7:0]  d_addr,
    output logic [7:0]  d_out,
    output logic        we,

    // completion flag
    output logic        done,

    // branch/jump override
    output logic        pc_load,
    output logic [7:0]  pc_target,

    // expose FSM state for fetch freeze
    output logic [1:0]  state_out
);

  // --- Decode ---
  logic [3:0]        opcode;
  logic [1:0]        rd_field;
  logic [1:0]        rs_field;
  logic [2:0]        imm3;
  logic signed [4:0] offset5;
  logic [4:0]        target5;

  always_comb begin
    opcode    = instr[8:5];
    rd_field  = instr[4:3];
    rs_field  = instr[2:1];
    imm3      = instr[2:0];
    offset5   = $signed(instr[4:0]);
    target5   = instr[4:0];
  end

  // --- Register file ---
  logic [7:0] rd_data, rs_data, rf_wdata;
  logic       rf_we;

  regfile rf (
    .clk        (clk),
    .reset      (reset),  
    .reg_write  (rf_we),
    .rd_addr    (rd_field),
    .rs_addr    (rs_field),
    .write_data (rf_wdata),
    .rd_data    (rd_data),
    .rs_data    (rs_data)
  );

  // --- ALU + flags ---
  logic [7:0]  alu_res;
  logic [3:0]  alu_op;
  logic        shift_flag_c, carry_flag_c;
  logic        shift_flag, carry_flag;

  assign alu_op = opcode;
  alu u_alu (
    .A          (rd_data),
    .B          (rs_data),
    .opcode     (alu_op),
    .result     (alu_res),
    .shift_flag (shift_flag_c),
    .carry_flag (carry_flag_c)
  );

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      shift_flag <= 1'b0;
      carry_flag <= 1'b0;
    end else begin
      shift_flag <= shift_flag_c;
      carry_flag <= carry_flag_c;
    end
    $display("DEBUG: clk=%0t | state=%0d | opcode=%b | rs=%0d | rd=%0d | core_instr=%09b", $time, state, opcode, rs_data, rd_data, instr);
  end

  // --- EXT Pending State ---
  logic ext_latched;
  logic [1:0] ext_rd;
  logic [7:0] ext_val;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) ext_latched <= 1'b0;
    else if (ext_valid) begin
      ext_latched <= 1'b1;
      ext_rd      <= instr[4:3];
      ext_val     <= ext_data;
    end else if (rf_we && opcode == 4'b0110 && ext_latched && ext_rd == rd_field) begin
      // Clear EXT pending after LDI for this reg
      ext_latched <= 1'b0;
    end
  end

  // --- FSM ---
  typedef enum logic [1:0] {FETCH = 2'b00, EXECUTE = 2'b01, MEM = 2'b10, HALTED = 2'b11} state_t;
  state_t state, next_state;
  logic done_r;

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      state <= FETCH;
    else
      state <= next_state;
  end
  assign state_out = state;

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      done_r <= 1'b0;
    else if ((state == EXECUTE) && (opcode == 4'b1101)) // HALT
      done_r <= 1'b1;
  end
  assign done = done_r;

  // --- Memory interface (default assignments) ---
  assign d_addr = rs_data;
  assign d_out  = rd_data;
  assign we     = (state == MEM) && (opcode == 4'b1001);

  // --- Main FSM/control ---
  always_comb begin
    rf_we     = 1'b0;
    pc_load   = 1'b0;
    pc_target = 8'h00;
    rf_wdata  = alu_res;
    next_state= FETCH;

    case (state)
      FETCH: 
        if (!start && !done_r) next_state = EXECUTE;

      EXECUTE: begin
        if (done_r) begin
          next_state = HALTED;
        end else begin
          case (opcode)
            // R-type ops
            4'b0000,4'b0001,4'b0010,4'b0011,4'b0100,4'b0101: begin
              rf_we     = 1'b1;
              rf_wdata  = alu_res;
              next_state= FETCH;
            end

            // I-type LDI rd, imm
            4'b0110: begin
              rf_we = 1'b1;
              if (ext_latched && ext_rd == rd_field)
                rf_wdata = ext_val;           // Use EXT value
              else
                rf_wdata = {5'b0, imm3};      // Standard 3-bit immediate
              next_state = FETCH;
            end

            // I-type ADDI rd, rs, imm
            4'b0111: begin
              rf_we     = 1'b1;
              rf_wdata  = rs_data + {{5{imm3[2]}}, imm3}; // Sign-extend imm3
              next_state= FETCH;
            end

            // Memory ops go to MEM state
            4'b1000, 4'b1001: next_state = MEM;

            // BNE
            4'b1010: begin
              if (rs_data != 8'h00) begin
                pc_load   = 1'b1;
                pc_target = pc + offset5;
              end
              next_state= FETCH;
            end

            // BEQ
            4'b1011: begin
              if (rs_data == 8'h00) begin
                pc_load   = 1'b1;
                pc_target = pc + offset5;
              end
              next_state= FETCH;
            end

            // J (jump)
            4'b1100: begin
              pc_load   = 1'b1;
              pc_target = target5;
              next_state= FETCH;
            end

            // HALT
            4'b1101: begin
              next_state = HALTED;
            end

            // EXT prefix: just latch, do *not* write register
            4'b1110: begin
              next_state = FETCH;
            end

            default: next_state = FETCH;
          endcase
        end
      end

      MEM: begin
        case (opcode)
          4'b1000: begin // LD rd, [rs]
            rf_we     = 1'b1;
            rf_wdata  = d_in;
            next_state= FETCH;
          end
          4'b1001: begin // ST [rs], rd
            next_state= FETCH;
            $display("STORE: mem[%0d] <= %0d", rs_data, rd_data);
          end
          default: next_state= FETCH;
        endcase
      end

      HALTED: begin
        next_state = HALTED;
      end

      default: next_state = FETCH;
    endcase
  end
endmodule