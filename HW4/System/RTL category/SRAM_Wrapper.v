`timescale 1ns/10ps
`include "../include/define.v"

module SRAM_Wrapper(
    input                           bus_clk,
    input                           bus_rst,
    input      [`BUS_ADDR_BITS-1:0] ADDR_S,
    input      [`BUS_DATA_BITS-1:0] WDATA_S,
    input      [`BUS_LEN_BITS -1:0] BLEN_S,
    input                           WLAST_S,
    input                           WVALID_S,
    input                           RVALID_S,
    output reg [`BUS_DATA_BITS-1:0] RDATA_S,
    output reg                      RLAST_S,
    output reg                      WREADY_S,
    output reg                      RREADY_S,
    output reg [`BUS_DATA_BITS-1:0] SRAM_D,
    output reg [`BUS_ADDR_BITS-1:0] SRAM_A,
    input      [`BUS_DATA_BITS-1:0] SRAM_Q,
    output                          SRAM_ceb,
    output                          SRAM_web        
);  
    localparam [1:0] STANDBY = 2'd0, READ_OP = 2'd1, WRITE_OP = 2'd2;
    reg [1:0] current_state, next_state;
    reg [`BUS_LEN_BITS-1:0] transfer_count;

    always @(*) begin
        case (current_state)
            STANDBY:  next_state = RVALID_S ? READ_OP : WVALID_S ? WRITE_OP : STANDBY;
            READ_OP:  next_state = (transfer_count == BLEN_S - 1) ? STANDBY : READ_OP;
            WRITE_OP: next_state = WLAST_S ? STANDBY : WRITE_OP;
            default:  next_state = STANDBY;
        endcase
    end

    always @(posedge bus_clk or posedge bus_rst) begin
        if (bus_rst) begin 
            current_state <= STANDBY;
        end else begin
            current_state <= next_state;
        end
    end

    always @(posedge bus_clk or posedge bus_rst) begin
        if (bus_rst) begin
            transfer_count <= {`BUS_LEN_BITS{1'b0}};
            WREADY_S <= 1'b0;
            RREADY_S <= 1'b0;
            SRAM_A   <= {`BUS_ADDR_BITS{1'b0}};
            SRAM_D   <= {`BUS_DATA_BITS{1'b0}};
            RDATA_S  <= {`BUS_DATA_BITS{1'b0}};
            RLAST_S  <= 1'b0;
        end else begin
            case (current_state)
                STANDBY: begin
                    RLAST_S <= 1'b0;
                    transfer_count <= 0;
                    
                    if (RVALID_S) begin
                        RREADY_S <= 1'b1;
                        SRAM_A   <= ADDR_S;
                    end else if (WVALID_S) begin
                        WREADY_S <= 1'b1;
                        SRAM_A   <= ADDR_S;
                        SRAM_D   <= WDATA_S;
                    end else begin
                        RREADY_S <= 1'b0;
                    end
                end

                READ_OP: begin
                    RDATA_S  <= SRAM_Q;
                    RREADY_S <= 1'b0;
                    
                    if (transfer_count == BLEN_S - 1) begin
                        RLAST_S <= 1'b1;
                    end else begin
                        transfer_count <= transfer_count + 1;
                        SRAM_A <= SRAM_A + 1;
                    end
                end
                
                WRITE_OP: begin
                    SRAM_D <= WDATA_S;
                    WREADY_S <= 1'b0;
                    
                    if (transfer_count == BLEN_S - 1) begin
                        // End of transfer
                    end else begin
                        transfer_count <= transfer_count + 1;
                        SRAM_A <= SRAM_A + 1;
                    end
                end
            endcase
        end
    end

    assign SRAM_ceb = (current_state == READ_OP) || (current_state == WRITE_OP);
    assign SRAM_web = (current_state != WRITE_OP);

endmodule
