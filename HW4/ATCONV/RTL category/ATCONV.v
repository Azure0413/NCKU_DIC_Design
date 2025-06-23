`timescale 1ns/10ps

module ATCONV(
input clk,
input rst,
output reg ROM_rd,
output reg [11:0] iaddr,
input [15:0] idata,
output reg layer0_ceb,
output reg layer0_web,
output reg [11:0] layer0_A,
output reg [15:0] layer0_D,
input [15:0] layer0_Q,
output reg layer1_ceb,
output reg layer1_web,
output reg [11:0] layer1_A,
output reg [15:0] layer1_D,
input [15:0] layer1_Q,
output reg done
);

/////////////////////////////////
// Please write your code here //
/////////////////////////////////
// 狀態定義
parameter INIT = 3'd0;
parameter ATCONV_9PIXELS = 3'd1;
parameter LAYER0_WRITERELU = 3'd2;
parameter MAXPOOL_4PIXELS = 3'd3;
parameter LAYER1_WRITECEILING = 3'd4;
parameter FINISH = 3'd5;

reg [2:0] state, next_state;

// 卷積核與權重定義
wire signed [15:0] kernel [1:9];
assign kernel[1] = 16'hFFFF; // -1/16
assign kernel[2] = 16'hFFFE; // -2/16 = -1/8
assign kernel[3] = 16'hFFFF; // -1/16
assign kernel[4] = 16'hFFFC; // -4/16 = -1/4
assign kernel[5] = 16'h0010; // 16/16 = 1
assign kernel[6] = 16'hFFFC; // -4/16 = -1/4
assign kernel[7] = 16'hFFFF; // -1/16
assign kernel[8] = 16'hFFFE; // -2/16 = -1/8
assign kernel[9] = 16'hFFFF; // -1/16

wire signed [15:0] bias;
assign bias = 16'hFFF4; // -12/16 = -3/4

// 控制與數據暫存器
reg [11:0] center; // 中心像素座標 (row, column) = (center[11:6], center[5:0])
reg [3:0] counter;
reg signed [31:0] convSum; // 卷積計算結果
reg signed [15:0] pool_max; // 池化最大值

// 圖像參數常數
parameter LENGTH = 6'd63; // 圖像最大索引(0-63)
parameter ZERO = 6'd0;

// 計算atrous卷積的偏移座標
wire [5:0] cy_add2, cy_minus2, cx_add2, cx_minus2;
assign cy_add2 = center[11:6] + 6'd2;
assign cy_minus2 = center[11:6] - 6'd2;
assign cx_add2 = center[5:0] + 6'd2;
assign cx_minus2 = center[5:0] - 6'd2;

// 狀態轉換邏輯
always @(*) begin
    case (state)
        INIT: next_state = ATCONV_9PIXELS;
        ATCONV_9PIXELS: next_state = (counter == 4'd9) ? LAYER0_WRITERELU : ATCONV_9PIXELS;
        LAYER0_WRITERELU: next_state = (center == 12'd4095) ? MAXPOOL_4PIXELS : ATCONV_9PIXELS;
        MAXPOOL_4PIXELS: next_state = (counter == 4'd4) ? LAYER1_WRITECEILING : MAXPOOL_4PIXELS;
        LAYER1_WRITECEILING: next_state = (center == 12'd1023) ? FINISH : MAXPOOL_4PIXELS;
        FINISH: next_state = FINISH;
        default: next_state = INIT;
    endcase
end

// 狀態暫存器
always @(posedge clk or posedge rst) begin
    if (rst) state <= INIT;
    else state <= next_state;
end

// 計數器控制
always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter <= 4'd0;
    end
    else if (state == ATCONV_9PIXELS || state == MAXPOOL_4PIXELS) begin
        counter <= counter + 4'd1;
    end
    else if (state == LAYER0_WRITERELU || state == LAYER1_WRITECEILING) begin
        counter <= 4'd0;
    end
end

// 中心像素位置控制 - 修改以在Layer 0完成時重置center
always @(posedge clk or posedge rst) begin
    if (rst) begin
        center <= 12'd0;
    end
    else if (state == LAYER0_WRITERELU) begin
        if (center == 12'd4095) // 如果Layer 0處理完畢
            center <= 12'd0;    // 重置center，準備進入Layer 1處理
        else
            center <= center + 12'd1;
    end
    else if (state == LAYER1_WRITECEILING) begin
        center <= center + 12'd1;
    end
end

// ROM讀取控制
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ROM_rd <= 1'b0;
        iaddr <= 12'd0;
    end
    else if (state == ATCONV_9PIXELS) begin
        ROM_rd <= 1'b1;
        
        case (counter)
            0: begin // 中心點(0,0)
                iaddr[11:6] <= center[11:6];
                iaddr[5:0] <= center[5:0];
            end
            
            1: begin // 左上 (-2,-2)
                iaddr[11:6] <= ((center[11:6] == ZERO) || (center[11:6] == 6'd1)) ? ZERO : cy_minus2;
                iaddr[5:0] <= ((center[5:0] == ZERO) || (center[5:0] == 6'd1)) ? ZERO : cx_minus2;
            end
            2: begin // 上中 (-2,0)
                iaddr[11:6] <= ((center[11:6] == ZERO) || (center[11:6] == 6'd1)) ? ZERO : cy_minus2;
                iaddr[5:0] <= center[5:0];
            end
            3: begin // 右上 (-2,+2)
                iaddr[11:6] <= ((center[11:6] == ZERO) || (center[11:6] == 6'd1)) ? ZERO : cy_minus2;
                iaddr[5:0] <= ((center[5:0] == LENGTH - 6'd1) || (center[5:0] == LENGTH)) ? LENGTH : cx_add2;
            end
            
            4: begin // 左中 (0,-2)
                iaddr[11:6] <= center[11:6];
                iaddr[5:0] <= ((center[5:0] == ZERO) || (center[5:0] == 6'd1)) ? ZERO : cx_minus2;
            end
            5: begin // 右中 (0,+2)
                iaddr[11:6] <= center[11:6];
                iaddr[5:0] <= ((center[5:0] == LENGTH - 6'd1) || (center[5:0] == LENGTH)) ? LENGTH : cx_add2;
            end
            
            6: begin // 左下 (+2,-2)
                iaddr[11:6] <= ((center[11:6] == LENGTH - 6'd1) || (center[11:6] == LENGTH)) ? LENGTH : cy_add2;
                iaddr[5:0] <= ((center[5:0] == ZERO) || (center[5:0] == 6'd1)) ? ZERO : cx_minus2;
            end
            7: begin // 下中 (+2,0)
                iaddr[11:6] <= ((center[11:6] == LENGTH - 6'd1) || (center[11:6] == LENGTH)) ? LENGTH : cy_add2;
                iaddr[5:0] <= center[5:0];
            end
            8: begin // 右下 (+2,+2)
                iaddr[11:6] <= ((center[11:6] == LENGTH - 6'd1) || (center[11:6] == LENGTH)) ? LENGTH : cy_add2;
                iaddr[5:0] <= ((center[5:0] == LENGTH - 6'd1) || (center[5:0] == LENGTH)) ? LENGTH : cx_add2;
            end
            
            default: begin
                iaddr[11:6] <= center[11:6];
                iaddr[5:0] <= center[5:0];
            end
        endcase
    end
    else begin
        ROM_rd <= 1'b0;
    end
end

// Layer 0 存儲控制
always @(posedge clk or posedge rst) begin
    if (rst) begin
        layer0_ceb <= 1'b0; // 禁用
        layer0_web <= 1'b1; // 讀取模式
        layer0_A <= 12'd0;
        layer0_D <= 16'd0;
    end
    else if (state == LAYER0_WRITERELU) begin
        layer0_ceb <= 1'b1; // 啟用
        layer0_web <= 1'b0; // 寫入模式
        layer0_A <= center;
        
        // ReLU激活：負值為0
        layer0_D <= (convSum[31]) ? 16'd0 : convSum[19:4];
    end
    else if (state == MAXPOOL_4PIXELS) begin
        layer0_ceb <= 1'b1; // 啟用
        layer0_web <= 1'b1; // 讀取模式
        
        // 2x2池化窗口地址
        case (counter)
            0: layer0_A <= {center[9:5], 1'b0, center[4:0], 1'b0}; // 左上 (2*row, 2*col)
            1: layer0_A <= {center[9:5], 1'b0, center[4:0], 1'b1}; // 右上 (2*row, 2*col+1)
            2: layer0_A <= {center[9:5], 1'b1, center[4:0], 1'b0}; // 左下 (2*row+1, 2*col)
            3: layer0_A <= {center[9:5], 1'b1, center[4:0], 1'b1}; // 右下 (2*row+1, 2*col+1)
            default: layer0_A <= 12'd0;
        endcase
    end
    else begin
        layer0_ceb <= 1'b0; // 禁用
    end
end

// Layer 1 存儲控制和池化 - 修改以確保正確的最大值計算
always @(posedge clk or posedge rst) begin
    if (rst) begin
        layer1_ceb <= 1'b0; // 禁用
        layer1_web <= 1'b1; // 讀取模式
        layer1_A <= 12'd0;
        layer1_D <= 16'd0;
        pool_max <= 16'h8000; // 最小可能值
    end
    else if (state == MAXPOOL_4PIXELS) begin
        // 最大值計算 - 修改以確保在讀取有效數據後才進行比較
        if (counter == 1) begin  // 等待第一個像素讀取完成
            pool_max <= layer0_Q;
        end
        else if (counter > 1 && counter <= 4) begin  // 等待後續像素讀取完成並比較
            if ($signed(layer0_Q) > $signed(pool_max)) begin
                pool_max <= layer0_Q;
            end
        end
    end
    else if (state == LAYER1_WRITECEILING) begin
        layer1_ceb <= 1'b1; // 啟用
        layer1_web <= 1'b0; // 寫入模式
        layer1_A <= {2'b00, center[9:0]}; // 確保高2位為0
        
        // 向上取整：若小數部分有任何位為1，整數部分加1
        layer1_D <= {pool_max[15:4] + |pool_max[3:0], 4'b0000};
        
        pool_max <= 16'h8000; // 重置最大值
    end
    else begin
        layer1_ceb <= 1'b0; // 禁用
    end
end

// 卷積和計算
always @(posedge clk or posedge rst) begin
    if (rst) begin
        convSum <= {{16{bias[15]}}, bias, 4'b0000}; // 初始化為偏置值
    end
    else if (state == ATCONV_9PIXELS) begin
        if (counter == 0) begin
            // 重置卷積和，初始為偏置值
            convSum <= {{16{bias[15]}}, bias, 4'b0000};
        end
        else begin
            // 修正：正確映射像素和卷積核權重
            case (counter)
                1: convSum <= convSum + $signed(idata) * $signed(kernel[5]); // 中心
                2: convSum <= convSum + $signed(idata) * $signed(kernel[1]); // 左上
                3: convSum <= convSum + $signed(idata) * $signed(kernel[2]); // 上中
                4: convSum <= convSum + $signed(idata) * $signed(kernel[3]); // 右上
                5: convSum <= convSum + $signed(idata) * $signed(kernel[4]); // 左中
                6: convSum <= convSum + $signed(idata) * $signed(kernel[6]); // 右中
                7: convSum <= convSum + $signed(idata) * $signed(kernel[7]); // 左下
                8: convSum <= convSum + $signed(idata) * $signed(kernel[8]); // 下中
                9: convSum <= convSum + $signed(idata) * $signed(kernel[9]); // 右下
                default: convSum <= convSum;
            endcase
        end
    end
end

// done信號控制
always @(posedge clk or posedge rst) begin
    if (rst) begin
        done <= 1'b0;
    end
    else if (state == FINISH) begin
        done <= 1'b1;
    end
end

endmodule