`timescale 1ns/10ps
`include "./include/define.v"

module ATCONV_Wrapper(
    input                              bus_clk  ,
    input                              bus_rst  ,
    input         [`BUS_DATA_BITS-1:0] RDATA_M  ,
    input                              RLAST_M  ,
    input                              WREADY_M ,
    input                              RREADY_M ,
    output reg    [`BUS_ID_BITS  -1:0] ID_M     ,
    output reg    [`BUS_ADDR_BITS-1:0] ADDR_M   ,
    output reg    [`BUS_DATA_BITS-1:0] WDATA_M  ,
    output        [`BUS_LEN_BITS -1:0] BLEN_M   ,
    output reg                         WLAST_M  ,
    output reg                         WVALID_M ,
    output reg                         RVALID_M ,
    output                             done   
);

    reg [`BUS_ADDR_BITS-1:0] img_addr;
    reg [`BUS_ADDR_BITS-1:0] mem0_addr;
    reg [`BUS_DATA_BITS-1:0] mem0_write_data;
    reg [`BUS_DATA_BITS-1:0] mem0_read_data;
    reg [`BUS_ADDR_BITS-1:0] mem1_addr;
    reg [`BUS_DATA_BITS-1:0] mem1_write_data;
    reg [`BUS_DATA_BITS-1:0] mem1_read_data;       
          
    parameter [3:0] ST_INIT                = 4'd0;
    parameter [3:0] ST_ROM_REQ             = 4'd1;
    parameter [3:0] ST_ROM_DATA            = 4'd2;
    parameter [3:0] ST_COMPUTE             = 4'd3;
    parameter [3:0] ST_MEM0_WR_REQ         = 4'd4;
    parameter [3:0] ST_MEM0_WR_DATA        = 4'd5;
    parameter [3:0] ST_MEM0_RD_REQ         = 4'd6;
    parameter [3:0] ST_MEM0_RD_DATA        = 4'd7;
    parameter [3:0] ST_POOL                = 4'd8;
    parameter [3:0] ST_MEM1_WR_REQ         = 4'd9;
    parameter [3:0] ST_MEM1_WR_DATA        = 4'd10;
    parameter [3:0] ST_COMPLETE            = 4'd11;

    reg [3:0] curr_state, next_state;
    reg [3:0] burst_len;
    reg [3:0] tx_counter;
    assign BLEN_M = burst_len;
    
    always @(*) begin
        WVALID_M = 1'b0;
        WLAST_M  = 1'b0;
        RVALID_M = 1'b0;
        ID_M     = 2'd3;
        ADDR_M   = 12'd0;
        burst_len = 4'd1; 
        
        case(curr_state)
            ST_ROM_REQ: begin
                RVALID_M = 1'd1;
                ID_M     = 2'd0;
                ADDR_M   = img_addr;
                burst_len = 4'b0001;
            end
            ST_ROM_DATA: begin
                RVALID_M = 1'd0;
                ID_M     = 2'd0;
                ADDR_M   = img_addr;
                burst_len = 4'b0001;
            end
            ST_COMPUTE: ;
            ST_MEM0_WR_REQ: begin
                WVALID_M = 1'd1;
                ID_M     = 2'd1;
                ADDR_M   = mem0_addr;
                WDATA_M  = mem0_write_data;
                burst_len = 4'b0001;
            end
            ST_MEM0_WR_DATA: begin
                WVALID_M = 1'd0;
                ID_M     = 2'd1;
                ADDR_M   = mem0_addr;
                WDATA_M  = mem0_write_data;
                burst_len = 4'b0001;
                if (tx_counter == burst_len - 1) begin
                    WLAST_M = 1'b1;
                end
            end
            ST_MEM0_RD_REQ: begin
                RVALID_M = 1'd1;
                ID_M     = 2'd1;
                ADDR_M   = mem0_addr;
                burst_len = 4'b0001;
            end
            ST_MEM0_RD_DATA: begin
                RVALID_M = 1'd0;
                ID_M     = 2'd1;
                ADDR_M   = mem0_addr;
                burst_len = 4'b0001;
            end
            ST_MEM1_WR_REQ: begin
                WVALID_M = 1'd1;
                ID_M     = 2'd2;
                ADDR_M   = mem1_addr;
                WDATA_M  = mem1_write_data;
                burst_len = 4'b0001;
            end
            ST_MEM1_WR_DATA: begin
                WVALID_M = 1'b0;
                ID_M     = 2'd2;
                ADDR_M   = mem1_addr;
                WDATA_M  = mem1_write_data;
                burst_len = 4'b0001;
                if (tx_counter == burst_len - 1) begin
                    WLAST_M = 1'b1;
                end
            end
            default: begin
                // Default values already set
            end
        endcase
    end

    parameter signed[15:0] KERNEL_0 = 16'hFFFF; 
    parameter signed[15:0] KERNEL_1 = 16'hFFFE; 
    parameter signed[15:0] KERNEL_2 = 16'hFFFF; 
    parameter signed[15:0] KERNEL_3 = 16'hFFFC; 
    parameter signed[15:0] KERNEL_4 = 16'h0010; 
    parameter signed[15:0] KERNEL_5 = 16'hFFFC;
    parameter signed[15:0] KERNEL_6 = 16'hFFFF;
    parameter signed[15:0] KERNEL_7 = 16'hFFFE;
    parameter signed[15:0] KERNEL_8 = 16'hFFFF;
    parameter signed[31:0] KERNEL_BIAS = 32'hFFFFFFF4;

    reg [15:0] conv_window [0:2][0:2];
    reg [3:0]  window_idx;
    reg [12:0] conv_center;
    reg signed [31:0] conv_output;
    reg signed [31:0] relu_output;

    wire signed [31:0] partial_0, partial_1, partial_2, partial_3, partial_4;
    wire signed [31:0] partial_5, partial_6, partial_7, partial_8;

    assign partial_0 = ($signed(conv_window[0][0]) * KERNEL_0) >>> 4;
    assign partial_1 = ($signed(conv_window[0][1]) * KERNEL_1) >>> 4;
    assign partial_2 = ($signed(conv_window[0][2]) * KERNEL_2) >>> 4;
    assign partial_3 = ($signed(conv_window[1][0]) * KERNEL_3) >>> 4;
    assign partial_4 = ($signed(conv_window[1][1]) * KERNEL_4) >>> 4;
    assign partial_5 = ($signed(conv_window[1][2]) * KERNEL_5) >>> 4;
    assign partial_6 = ($signed(conv_window[2][0]) * KERNEL_6) >>> 4;
    assign partial_7 = ($signed(conv_window[2][1]) * KERNEL_7) >>> 4;
    assign partial_8 = ($signed(conv_window[2][2]) * KERNEL_8) >>> 4;
    
    always@(*) begin
        conv_output = partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + 
                      partial_5 + partial_6 + partial_7 + partial_8 + KERNEL_BIAS;
        relu_output = (conv_output[31]) ? 32'd0 : conv_output;
    end
    
    reg [15:0] pool_buffer [0:1][0:1];
    reg [1:0]  pool_idx;
    reg [11:0] mem0_read_pos;

    reg [11:0] mem1_write_pos;
    reg [5:0]  row_idx;
    reg [5:0]  col_idx;

    reg [15:0] max_val1, max_val2, max_val, frac_part, int_part;
    reg [15:0] pool_result;
    parameter [15:0] FRACTION_MASK = 16'b0000_0000_0000_1111;
    parameter [15:0] INTEGER_MASK  = 16'b1111_1111_1111_0000;

    always@(*) begin
        max_val1 = (pool_buffer[0][0] > pool_buffer[0][1]) ? pool_buffer[0][0] : pool_buffer[0][1];
        max_val2 = (pool_buffer[1][0] > pool_buffer[1][1]) ? pool_buffer[1][0] : pool_buffer[1][1];
        max_val = (max_val1 > max_val2) ? max_val1 : max_val2;
        
        frac_part = FRACTION_MASK & max_val;
        int_part = max_val & INTEGER_MASK;
        pool_result = (frac_part > 0) ? (int_part + 16'd16) : int_part;
    end

    always@(*) begin
        case(curr_state)
            ST_INIT                : next_state = ST_ROM_REQ;
            ST_ROM_REQ             : next_state = (RVALID_M && RREADY_M) ? ST_ROM_DATA : ST_ROM_REQ;
            ST_ROM_DATA            : next_state = (RLAST_M) ? ((window_idx == 8) ? ST_COMPUTE : ST_ROM_REQ) : ST_ROM_DATA;
            ST_COMPUTE             : next_state = ST_MEM0_WR_REQ;
            ST_MEM0_WR_REQ         : next_state = (WVALID_M && WREADY_M) ? ST_MEM0_WR_DATA : ST_MEM0_WR_REQ;
            ST_MEM0_WR_DATA        : next_state = (conv_center == 4095) ? ST_MEM0_RD_REQ : ST_ROM_REQ;
            ST_MEM0_RD_REQ         : next_state = (RVALID_M && RREADY_M) ? ST_MEM0_RD_DATA : ST_MEM0_RD_REQ;
            ST_MEM0_RD_DATA        : next_state = (pool_idx == 3) ? ST_POOL : ST_MEM0_RD_REQ;
            ST_POOL                : next_state = ST_MEM1_WR_REQ;
            ST_MEM1_WR_REQ         : next_state = (WVALID_M && WREADY_M) ? ST_MEM1_WR_DATA : ST_MEM1_WR_REQ;
            ST_MEM1_WR_DATA        : next_state = (mem1_write_pos == 1023) ? ST_COMPLETE : ST_MEM0_RD_REQ;
            ST_COMPLETE            : next_state = ST_COMPLETE;
        endcase
    end

    parameter ATROUS_RATE = 2;

    wire signed[7:0] center_row = {2'b00, conv_center[11:6]};
    wire signed[7:0] center_col = {2'b00, conv_center[5:0]};
    reg signed [7:0] row_offset, col_offset;

    always @(*) begin
        case (window_idx)
            4'd0: begin row_offset = -ATROUS_RATE; col_offset = -ATROUS_RATE; end
            4'd1: begin row_offset = -ATROUS_RATE; col_offset =  0;           end
            4'd2: begin row_offset = -ATROUS_RATE; col_offset =  ATROUS_RATE; end
            4'd3: begin row_offset =  0;           col_offset = -ATROUS_RATE; end
            4'd4: begin row_offset =  0;           col_offset =  0;           end
            4'd5: begin row_offset =  0;           col_offset =  ATROUS_RATE; end
            4'd6: begin row_offset =  ATROUS_RATE; col_offset = -ATROUS_RATE; end
            4'd7: begin row_offset =  ATROUS_RATE; col_offset =  0;           end
            4'd8: begin row_offset =  ATROUS_RATE; col_offset =  ATROUS_RATE; end
            default: begin row_offset = 0; col_offset = 0; end
        endcase
    end

    wire signed [7:0] target_row_temp = center_row + row_offset;
    wire signed [7:0] target_col_temp = center_col + col_offset;
    wire [5:0] target_row = target_row_temp < 0 ? 6'd0 : target_row_temp > 63 ? 6'd63 : target_row_temp[5:0];
    wire [5:0] target_col = target_col_temp < 0 ? 6'd0 : target_col_temp > 63 ? 6'd63 : target_col_temp[5:0];

    always @(*) begin
        img_addr = {target_row, target_col};
    end

    parameter [1:0] POOL_STRIDE = 2'd2;
    reg pool_row_offset, pool_col_offset;
    
    always @(*) begin
        case (pool_idx)
            2'd0: begin pool_row_offset = 1'd0; pool_col_offset = 1'd0; end
            2'd1: begin pool_row_offset = 1'd0; pool_col_offset = 1'd1; end
            2'd2: begin pool_row_offset = 1'd1; pool_col_offset = 1'd0; end
            2'd3: begin pool_row_offset = 1'd1; pool_col_offset = 1'd1; end
            default: begin pool_row_offset = 1'd0; pool_col_offset = 1'd0; end
        endcase
    end

    always@(*) begin
        row_idx = {mem1_write_pos[9:5], pool_row_offset};
        col_idx = {mem1_write_pos[4:0], pool_col_offset};
        mem0_read_pos = {row_idx, col_idx}; 
    end

    always@(*) begin
        mem0_addr = 12'd0;
        mem0_write_data = 16'd0;

        case (curr_state)
            ST_MEM0_WR_REQ: begin
                mem0_addr = conv_center;
                mem0_write_data = relu_output[15:0];
            end
            ST_MEM0_RD_REQ: begin
                mem0_addr = mem0_read_pos;
            end
            default: begin
                // Keep default values
            end
        endcase
    end

    always@(*) begin
        if(curr_state == ST_MEM1_WR_REQ) begin
            mem1_addr = mem1_write_pos;
            mem1_write_data = pool_result;
        end
    end

    always@(posedge bus_clk, posedge bus_rst) begin
        if (bus_rst) begin
            curr_state <= ST_INIT;      
        end else begin
            curr_state <= next_state;
        end
    end

    always @(posedge bus_clk or posedge bus_rst) begin
        if (bus_rst) begin
            window_idx <= 4'd0;
            conv_center <= 12'd0; 
            pool_idx <= 2'd0;
            mem1_write_pos <= 12'd0;
            tx_counter <= 4'd0;
        end else begin
            case (curr_state)
                ST_ROM_DATA: begin
                    conv_window[window_idx/3][window_idx%3] <= RDATA_M;
                    window_idx <= window_idx + 1;
                end
                ST_COMPUTE: begin
                    window_idx <= 4'd0;
                end
                ST_MEM0_WR_DATA: begin
                    conv_center <= conv_center + 1;
                end
                ST_MEM0_RD_DATA: begin
                    pool_buffer[pool_row_offset][pool_col_offset] <= RDATA_M;
                    pool_idx <= pool_idx + 1;
                end
                ST_POOL: begin
                    pool_idx <= 2'd0;
                end
                ST_MEM1_WR_DATA: begin
                    mem1_write_pos <= mem1_write_pos + 1;
                end
                default: begin
                    // No action needed for other states
                end
            endcase
        end
    end   

    assign done = (curr_state == ST_COMPLETE) ? 1 : 0;

endmodule
