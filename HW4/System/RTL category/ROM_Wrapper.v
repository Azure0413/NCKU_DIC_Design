`timescale 1ns/10ps
`include "../include/define.v"

module ROM_Wrapper(
    input                            bus_clk,
    input                            bus_rst,
    input      [`BUS_ADDR_BITS-1:0]  ADDR_S,
    input      [`BUS_LEN_BITS -1:0]  BLEN_S,
    input                            RVALID_S,
    output reg [`BUS_DATA_BITS-1:0]  RDATA_S,
    output reg                       RLAST_S,
    output reg                       RREADY_S,
    output reg                       ROM_rd,
    output reg [`BUS_ADDR_BITS-1:0]  ROM_A,
    input      [`BUS_DATA_BITS-1:0]  ROM_Q 
);
    localparam WAIT_CMD = 2'd0, READ_DATA = 2'd1;
    reg [1:0] current_state, next_state;
    reg [`BUS_LEN_BITS-1:0] transfer_count;

    always @(*) begin
        case (current_state)
            WAIT_CMD:   next_state = RVALID_S ? READ_DATA : WAIT_CMD;
            READ_DATA:  next_state = (transfer_count == BLEN_S - 1) ? WAIT_CMD : READ_DATA;
            default:    next_state = WAIT_CMD;
        endcase
    end

    always @(posedge bus_clk or posedge bus_rst) begin
        if (bus_rst) begin 
            current_state <= WAIT_CMD;
        end else begin
            current_state <= next_state;
        end
    end

    always @(posedge bus_clk or posedge bus_rst) begin
        if (bus_rst) begin
            transfer_count <= {`BUS_LEN_BITS{1'b0}};
            RREADY_S <= 1'b0;
            ROM_rd   <= 1'b0;
            ROM_A    <= {`BUS_ADDR_BITS{1'b0}};
            RDATA_S  <= {`BUS_DATA_BITS{1'b0}};
            RLAST_S  <= 1'b0;
        end else begin
            case (current_state)
                WAIT_CMD: begin
                    RLAST_S <= 1'b0;
                    transfer_count <= 0;
                    RREADY_S <= 1'b0;
                    ROM_rd   <= 1'b0;
                    
                    if (RVALID_S) begin
                        RREADY_S <= 1'b1;
                        ROM_rd   <= 1'b1;
                        ROM_A    <= ADDR_S;
                    end 
                end

                READ_DATA: begin
                    RDATA_S <= ROM_Q;
                    RREADY_S <= 1'b0;
                    
                    if (transfer_count == BLEN_S - 1) begin
                        RLAST_S <= 1'b1;
                        ROM_rd  <= 1'b0;
                    end else begin
                        transfer_count <= transfer_count + 1;
                        ROM_A    <= ROM_A + 1;
                        ROM_rd   <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
