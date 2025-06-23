module FFT(
input clk,
input rst,
input [15:0] fir_d,
input fir_valid,
output reg fft_valid,
output reg done,
output reg [15:0] fft_d0,
output reg [15:0] fft_d1,
output reg [15:0] fft_d2,
output reg [15:0] fft_d3,
output reg [15:0] fft_d4,
output reg [15:0] fft_d5,
output reg [15:0] fft_d6,
output reg [15:0] fft_d7,
output reg [15:0] fft_d8,
output reg [15:0] fft_d9,
output reg [15:0] fft_d10,
output reg [15:0] fft_d11,
output reg [15:0] fft_d12,
output reg [15:0] fft_d13,
output reg [15:0] fft_d14,
output reg [15:0] fft_d15
);

parameter signed [31:0] W_R0 = 32'h00010000;
parameter signed [31:0] W_R1 = 32'h0000EC83;
parameter signed [31:0] W_R2 = 32'h0000B504;
parameter signed [31:0] W_R3 = 32'h000061F7;
parameter signed [31:0] W_R4 = 32'h00000000;
parameter signed [31:0] W_R5 = 32'hFFFF9E09;
parameter signed [31:0] W_R6 = 32'hFFFF4AFC;
parameter signed [31:0] W_R7 = 32'hFFFF137D;

parameter signed [31:0] W_I0 = 32'h00000000;
parameter signed [31:0] W_I1 = 32'hFFFF9E09;
parameter signed [31:0] W_I2 = 32'hFFFF4AFC;
parameter signed [31:0] W_I3 = 32'hFFFF137D;
parameter signed [31:0] W_I4 = 32'hFFFF0000;
parameter signed [31:0] W_I5 = 32'hFFFF137D;
parameter signed [31:0] W_I6 = 32'hFFFF4AFC;
parameter signed [31:0] W_I7 = 32'hFFFF9E09;

reg [5:0] cnt;
reg signed [15:0] y [15:0];
reg signed [63:0] fft_in [15:0];
reg signed [63:0] fft_s1_R [15:0];
reg signed [63:0] fft_s1_I [15:0];
reg signed [63:0] fft_s2_R [15:0];
reg signed [63:0] fft_s2_I [15:0];
reg signed [63:0] fft_s3_R [15:0];
reg signed [63:0] fft_s3_I [15:0];
reg signed [63:0] fft_s4_R [15:0];
reg signed [63:0] fft_s4_I [15:0];
reg fft_in_valid, fft_s1_valid, fft_s2_valid, fft_s3_valid, fft_s4_valid;
reg [2:0] output_state;
reg [5:0] output_count;
reg data_complete;
integer i, j;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (j = 0; j < 16; j = j + 1) begin
            y[j] <= 0;
        end
    end
    else begin
        if (!fir_valid) begin
            for (j = 0; j < 16; j = j + 1) begin
                y[j] <= 0;
            end
        end
        else begin
            y[15] <= fir_d;
            for (j = 15; j > 0; j = j - 1) begin
                y[j-1] <= y[j];
            end
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (j = 0; j < 16; j = j + 1) begin
            fft_in[j] <= 0;
            fft_in_valid <= 0;
        end
    end
    else begin
        if (cnt == 16) begin
            fft_in_valid <= 1;
            for (j = 0; j < 16; j = j + 1) begin
                fft_in[j] <= { {24{y[j][15]}}, y[j], 24'b0 };
            end
        end
        else begin
            fft_in_valid <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (j = 0; j < 16; j = j + 1) begin
            fft_s1_R[j] <= 0;
            fft_s1_I[j] <= 0;
            fft_s1_valid <= 0;
        end
    end
    else begin
        if (fft_in_valid) begin
            fft_s1_valid <= 1;
            fft_s1_R[0] <= fft_in[0] + fft_in[8];
            fft_s1_I[0] <= 64'b0;
            fft_s1_R[8] <= ((fft_in[0] - fft_in[8]) * W_R0) >>> 16;
            fft_s1_I[8] <= ((fft_in[0] - fft_in[8]) * W_I0) >>> 16;
            
            fft_s1_R[1] <= fft_in[1] + fft_in[9];
            fft_s1_I[1] <= 64'b0;
            fft_s1_R[9] <= ((fft_in[1] - fft_in[9]) * W_R1) >>> 16;
            fft_s1_I[9] <= ((fft_in[1] - fft_in[9]) * W_I1) >>> 16;
            
            fft_s1_R[2] <= fft_in[2] + fft_in[10];
            fft_s1_I[2] <= 64'b0;
            fft_s1_R[10] <= ((fft_in[2] - fft_in[10]) * W_R2) >>> 16;
            fft_s1_I[10] <= ((fft_in[2] - fft_in[10]) * W_I2) >>> 16;
            
            fft_s1_R[3] <= fft_in[3] + fft_in[11];
            fft_s1_I[3] <= 64'b0;
            fft_s1_R[11] <= ((fft_in[3] - fft_in[11]) * W_R3) >>> 16;
            fft_s1_I[11] <= ((fft_in[3] - fft_in[11]) * W_I3) >>> 16;
            
            fft_s1_R[4] <= fft_in[4] + fft_in[12];
            fft_s1_I[4] <= 64'b0;
            fft_s1_R[12] <= ((fft_in[4] - fft_in[12]) * W_R4) >>> 16;
            fft_s1_I[12] <= ((fft_in[4] - fft_in[12]) * W_I4) >>> 16;
            
            fft_s1_R[5] <= fft_in[5] + fft_in[13];
            fft_s1_I[5] <= 64'b0;
            fft_s1_R[13] <= ((fft_in[5] - fft_in[13]) * W_R5) >>> 16;
            fft_s1_I[13] <= ((fft_in[5] - fft_in[13]) * W_I5) >>> 16;
            
            fft_s1_R[6] <= fft_in[6] + fft_in[14];
            fft_s1_I[6] <= 64'b0;
            fft_s1_R[14] <= ((fft_in[6] - fft_in[14]) * W_R6) >>> 16;
            fft_s1_I[14] <= ((fft_in[6] - fft_in[14]) * W_I6) >>> 16;
            
            fft_s1_R[7] <= fft_in[7] + fft_in[15];
            fft_s1_I[7] <= 64'b0;
            fft_s1_R[15] <= ((fft_in[7] - fft_in[15]) * W_R7) >>> 16;
            fft_s1_I[15] <= ((fft_in[7] - fft_in[15]) * W_I7) >>> 16;
        end
        else begin
            fft_s1_valid <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (j = 0; j < 16; j = j + 1) begin
            fft_s2_R[j] <= 0;
            fft_s2_I[j] <= 0;
            fft_s2_valid <= 0;
        end
    end
    else begin
        if (fft_s1_valid) begin
            fft_s2_valid <= 1;
            for (i = 0; i < 2; i = i + 1) begin
                fft_s2_R[i*8+0] <= fft_s1_R[i*8+0] + fft_s1_R[i*8+4];
                fft_s2_I[i*8+0] <= fft_s1_I[i*8+0] + fft_s1_I[i*8+4];
                fft_s2_R[i*8+4] <= (((fft_s1_R[i*8+0] - fft_s1_R[i*8+4]) * W_R0) - ((fft_s1_I[i*8+0] - fft_s1_I[i*8+4]) * W_I0)) >>> 16;
                fft_s2_I[i*8+4] <= (((fft_s1_R[i*8+0] - fft_s1_R[i*8+4]) * W_I0) + ((fft_s1_I[i*8+0] - fft_s1_I[i*8+4]) * W_R0)) >>> 16;
                
                fft_s2_R[i*8+1] <= fft_s1_R[i*8+1] + fft_s1_R[i*8+5];
                fft_s2_I[i*8+1] <= fft_s1_I[i*8+1] + fft_s1_I[i*8+5];
                fft_s2_R[i*8+5] <= (((fft_s1_R[i*8+1] - fft_s1_R[i*8+5]) * W_R2) - ((fft_s1_I[i*8+1] - fft_s1_I[i*8+5]) * W_I2)) >>> 16;
                fft_s2_I[i*8+5] <= (((fft_s1_R[i*8+1] - fft_s1_R[i*8+5]) * W_I2) + ((fft_s1_I[i*8+1] - fft_s1_I[i*8+5]) * W_R2)) >>> 16;
                
                fft_s2_R[i*8+2] <= fft_s1_R[i*8+2] + fft_s1_R[i*8+6];
                fft_s2_I[i*8+2] <= fft_s1_I[i*8+2] + fft_s1_I[i*8+6];
                fft_s2_R[i*8+6] <= (((fft_s1_R[i*8+2] - fft_s1_R[i*8+6]) * W_R4) - ((fft_s1_I[i*8+2] - fft_s1_I[i*8+6]) * W_I4)) >>> 16;
                fft_s2_I[i*8+6] <= (((fft_s1_R[i*8+2] - fft_s1_R[i*8+6]) * W_I4) + ((fft_s1_I[i*8+2] - fft_s1_I[i*8+6]) * W_R4)) >>> 16;
                
                fft_s2_R[i*8+3] <= fft_s1_R[i*8+3] + fft_s1_R[i*8+7];
                fft_s2_I[i*8+3] <= fft_s1_I[i*8+3] + fft_s1_I[i*8+7];
                fft_s2_R[i*8+7] <= (((fft_s1_R[i*8+3] - fft_s1_R[i*8+7]) * W_R6) - ((fft_s1_I[i*8+3] - fft_s1_I[i*8+7]) * W_I6)) >>> 16;
                fft_s2_I[i*8+7] <= (((fft_s1_R[i*8+3] - fft_s1_R[i*8+7]) * W_I6) + ((fft_s1_I[i*8+3] - fft_s1_I[i*8+7]) * W_R6)) >>> 16;
            end
        end
        else begin
            fft_s2_valid <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (j = 0; j < 16; j = j + 1) begin
            fft_s3_R[j] <= 0;
            fft_s3_I[j] <= 0;
            fft_s3_valid <= 0;
        end
    end
    else begin
        if (fft_s2_valid) begin
            fft_s3_valid <= 1;
            for (i = 0; i < 4; i = i + 1) begin
                fft_s3_R[i*4+0] <= fft_s2_R[i*4+0] + fft_s2_R[i*4+2];
                fft_s3_I[i*4+0] <= fft_s2_I[i*4+0] + fft_s2_I[i*4+2];
                fft_s3_R[i*4+2] <= (((fft_s2_R[i*4+0] - fft_s2_R[i*4+2]) * W_R0) - ((fft_s2_I[i*4+0] - fft_s2_I[i*4+2]) * W_I0)) >>> 16;
                fft_s3_I[i*4+2] <= (((fft_s2_R[i*4+0] - fft_s2_R[i*4+2]) * W_I0) + ((fft_s2_I[i*4+0] - fft_s2_I[i*4+2]) * W_R0)) >>> 16;
                
                fft_s3_R[i*4+1] <= fft_s2_R[i*4+1] + fft_s2_R[i*4+3];
                fft_s3_I[i*4+1] <= fft_s2_I[i*4+1] + fft_s2_I[i*4+3];
                fft_s3_R[i*4+3] <= (((fft_s2_R[i*4+1] - fft_s2_R[i*4+3]) * W_R4) - ((fft_s2_I[i*4+1] - fft_s2_I[i*4+3]) * W_I4)) >>> 16;
                fft_s3_I[i*4+3] <= (((fft_s2_R[i*4+1] - fft_s2_R[i*4+3]) * W_I4) + ((fft_s2_I[i*4+1] - fft_s2_I[i*4+3]) * W_R4)) >>> 16;
            end
        end
        else begin
            fft_s3_valid <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (j = 0; j < 16; j = j + 1) begin
            fft_s4_R[j] <= 0;
            fft_s4_I[j] <= 0;
            fft_s4_valid <= 0;
        end
    end
    else begin
        if (fft_s3_valid) begin
            fft_s4_valid <= 1;
            for (i = 0; i < 8; i = i + 1) begin
                fft_s4_R[i*2] <= fft_s3_R[i*2] + fft_s3_R[i*2+1];
                fft_s4_I[i*2] <= fft_s3_I[i*2] + fft_s3_I[i*2+1];
                fft_s4_R[i*2+1] <= (((fft_s3_R[i*2] - fft_s3_R[i*2+1]) * W_R0) - ((fft_s3_I[i*2] - fft_s3_I[i*2+1]) * W_I0)) >>> 16;
                fft_s4_I[i*2+1] <= (((fft_s3_R[i*2] - fft_s3_R[i*2+1]) * W_I0) + ((fft_s3_I[i*2] - fft_s3_I[i*2+1]) * W_R0)) >>> 16;
            end
        end
        else begin
            fft_s4_valid <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt <= 0;
    end
    else begin
        if (!fir_valid)
            cnt <= 0;
        else
            cnt <= (cnt == 6'd16) ? 6'd1 : cnt + 6'd1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        output_state <= 0;
        output_count <= 0;
        data_complete <= 0;
        fft_valid <= 0;
        done <= 0;
        fft_d0 <= 0; fft_d1 <= 0; fft_d2 <= 0; fft_d3 <= 0;
        fft_d4 <= 0; fft_d5 <= 0; fft_d6 <= 0; fft_d7 <= 0;
        fft_d8 <= 0; fft_d9 <= 0; fft_d10 <= 0; fft_d11 <= 0;
        fft_d12 <= 0; fft_d13 <= 0; fft_d14 <= 0; fft_d15 <= 0;
    end
    else begin
        case (output_state)
            0: begin
                if (fft_s4_valid) begin
                    output_state <= 1;
                    fft_valid <= 1;
                    
                    fft_d0 <= (fft_s4_R[0][39:8]) >>> 16;
                    fft_d1 <= (fft_s4_R[8][39:8]) >>> 16;
                    fft_d2 <= (fft_s4_R[4][39:8]) >>> 16;
                    fft_d3 <= (fft_s4_R[12][39:8]) >>> 16;
                    fft_d4 <= (fft_s4_R[2][39:8]) >>> 16;
                    fft_d5 <= (fft_s4_R[10][39:8]) >>> 16;
                    fft_d6 <= (fft_s4_R[6][39:8]) >>> 16;
                    fft_d7 <= (fft_s4_R[14][39:8]) >>> 16;
                    fft_d8 <= (fft_s4_R[1][39:8]) >>> 16;
                    fft_d9 <= (fft_s4_R[9][39:8]) >>> 16;
                    fft_d10 <= (fft_s4_R[5][39:8]) >>> 16;
                    fft_d11 <= (fft_s4_R[13][39:8]) >>> 16;
                    fft_d12 <= (fft_s4_R[3][39:8]) >>> 16;
                    fft_d13 <= (fft_s4_R[11][39:8]) >>> 16;
                    fft_d14 <= (fft_s4_R[7][39:8]) >>> 16;
                    fft_d15 <= (fft_s4_R[15][39:8]) >>> 16;
                end
                else begin
                    fft_valid <= 0;
                    done <= 0;
                end
            end
            
            1: begin
                output_state <= 2;
                fft_valid <= 1;
                
                fft_d0 <= (fft_s4_I[0][39:8]) >>> 16;
                fft_d1 <= (fft_s4_I[8][39:8]) >>> 16;
                fft_d2 <= (fft_s4_I[4][39:8]) >>> 16;
                fft_d3 <= (fft_s4_I[12][39:8]) >>> 16;
                fft_d4 <= (fft_s4_I[2][39:8]) >>> 16;
                fft_d5 <= (fft_s4_I[10][39:8]) >>> 16;
                fft_d6 <= (fft_s4_I[6][39:8]) >>> 16;
                fft_d7 <= (fft_s4_I[14][39:8]) >>> 16;
                fft_d8 <= (fft_s4_I[1][39:8]) >>> 16;
                fft_d9 <= (fft_s4_I[9][39:8]) >>> 16;
                fft_d10 <= (fft_s4_I[5][39:8]) >>> 16;
                fft_d11 <= (fft_s4_I[13][39:8]) >>> 16;
                fft_d12 <= (fft_s4_I[3][39:8]) >>> 16;
                fft_d13 <= (fft_s4_I[11][39:8]) >>> 16;
                fft_d14 <= (fft_s4_I[7][39:8]) >>> 16;
                fft_d15 <= (fft_s4_I[15][39:8]) >>> 16;
                
                output_count <= output_count + 1;
                if (output_count >= 63) begin
                    data_complete <= 1;
                end
            end
            
            2: begin
                fft_valid <= 0;
                if (data_complete) begin
                    done <= 1;
                    output_state <= 3;
                end
                else begin
                    output_state <= 0;
                end
            end
            
            3: begin
                done <= 1;
                fft_valid <= 0;
            end
        endcase
    end
end

endmodule
