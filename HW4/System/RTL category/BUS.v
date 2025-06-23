`timescale 1ns/10ps
`include "./include/define.v"

module BUS(
    input                           bus_clk  ,
    input                           bus_rst  ,

    // Master interface
    input   [`BUS_ID_BITS  -1:0]    ID_M0    ,
    input   [`BUS_ADDR_BITS-1:0]    ADDR_M0  ,
    input   [`BUS_DATA_BITS-1:0]    WDATA_M0 ,
    input   [`BUS_LEN_BITS -1:0]    BLEN_M0  ,
    input                           WLAST_M0 ,
    input                           WVALID_M0,
    input                           RVALID_M0,
    output reg [`BUS_DATA_BITS-1:0] RDATA_M0 ,
    output reg                      RLAST_M0 ,
    output                          WREADY_M0,
    output                          RREADY_M0,

    // Slave 0 (ROM) interface
    output  [`BUS_ADDR_BITS-1:0]    ADDR_S0  ,
    output  [`BUS_LEN_BITS -1:0]    BLEN_S0  ,
    output                          RVALID_S0,
    input   [`BUS_DATA_BITS-1:0]    RDATA_S0 ,
    input                           RLAST_S0 ,
    input                           RREADY_S0,

    // Slave 1 (SRAM0) interface
    output  [`BUS_ADDR_BITS-1:0]    ADDR_S1  ,
    output reg [`BUS_DATA_BITS-1:0] WDATA_S1 ,
    output  [`BUS_LEN_BITS -1:0]    BLEN_S1  ,
    output reg                      WLAST_S1 ,
    output                          WVALID_S1,
    output                          RVALID_S1,
    input   [`BUS_DATA_BITS-1:0]    RDATA_S1 ,
    input                           RLAST_S1 ,
    input                           WREADY_S1,
    input                           RREADY_S1,

    // Slave 2 (SRAM1) interface
    output  [`BUS_ADDR_BITS-1:0]    ADDR_S2  ,
    output reg [`BUS_DATA_BITS-1:0] WDATA_S2 ,
    output  [`BUS_LEN_BITS -1:0]    BLEN_S2  ,
    output reg                      WLAST_S2 ,
    output                          WVALID_S2,
    output                          RVALID_S2,
    input   [`BUS_DATA_BITS-1:0]    RDATA_S2 ,
    input                           RLAST_S2 ,
    input                           WREADY_S2,
    input                           RREADY_S2
);

    assign ADDR_S0 = ADDR_M0;
    assign ADDR_S1 = ADDR_M0;
    assign ADDR_S2 = ADDR_M0;

    assign BLEN_S0 = BLEN_M0;
    assign BLEN_S1 = BLEN_M0;
    assign BLEN_S2 = BLEN_M0;

    assign RVALID_S0 = (ID_M0 == 2'd0) && RVALID_M0;
    assign RVALID_S1 = (ID_M0 == 2'd1) && RVALID_M0;
    assign RVALID_S2 = (ID_M0 == 2'd2) && RVALID_M0;

    assign WVALID_S1 = (ID_M0 == 2'd1) && WVALID_M0;
    assign WVALID_S2 = (ID_M0 == 2'd2) && WVALID_M0;

    wire ready_s0 = (ID_M0 == 2'd0) && RREADY_S0;
    wire ready_s1_r = (ID_M0 == 2'd1) && RREADY_S1;
    wire ready_s2_r = (ID_M0 == 2'd2) && RREADY_S2;
    wire ready_s1_w = (ID_M0 == 2'd1) && WREADY_S1;
    wire ready_s2_w = (ID_M0 == 2'd2) && WREADY_S2;
    
    assign RREADY_M0 = ready_s0 || ready_s1_r || ready_s2_r;
    assign WREADY_M0 = ready_s1_w || ready_s2_w;

    always @(*) begin
        RDATA_M0 = {`BUS_DATA_BITS{1'b0}};
        RLAST_M0 = 1'b0;
        WDATA_S1 = {`BUS_DATA_BITS{1'b0}};
        WLAST_S1 = 1'b0;
        WDATA_S2 = {`BUS_DATA_BITS{1'b0}};
        WLAST_S2 = 1'b0;

        case (ID_M0)
            2'd0: begin
                RDATA_M0 = RDATA_S0;
                RLAST_M0 = RLAST_S0;
            end
            2'd1: begin
                RDATA_M0 = RDATA_S1;
                RLAST_M0 = RLAST_S1;
                WDATA_S1 = WDATA_M0;
                WLAST_S1 = WLAST_M0;
            end
            2'd2: begin
                RDATA_M0 = RDATA_S2;
                RLAST_M0 = RLAST_S2;
                WDATA_S2 = WDATA_M0;
                WLAST_S2 = WLAST_M0;
            end
            default: begin
                // Default case - no connections
            end
        endcase
    end

endmodule
