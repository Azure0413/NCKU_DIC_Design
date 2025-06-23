module LCD_CTRL(
    input           clk,
    input           rst,
    input   [3:0]   cmd,
    input           cmd_valid,
    input   [7:0]   IROM_Q,
    output  reg     IROM_rd,
    output  reg [5:0] IROM_A,
    output  reg     IRAM_ceb,
    output  reg     IRAM_web,
    output  reg [7:0] IRAM_D,
    output  reg [5:0] IRAM_A,
    input   [7:0]   IRAM_Q,
    output  reg     busy,
    output  reg     done
);

    parameter READ       = 3'b000;
    parameter IDLE       = 3'b001;
    parameter OPERATIONS  = 3'b010;
    parameter WRITE      = 3'b011;
    parameter DONE       = 3'b100;
    parameter LOAD_WAIT    = 3'b101;
    parameter OUT_WAIT   = 3'b110;
    parameter FINAL_ADDR   = 6'd63;

    parameter WRITE_CMD = 4'b0000;
    parameter UP_CMD      = 4'b0001;
    parameter DOWN_CMD    = 4'b0010;
    parameter LEFT_CMD    = 4'b0011;
    parameter RIGHT_CMD   = 4'b0100;
    parameter MAX           = 4'b0101;
    parameter MIN           = 4'b0110;
    parameter AVERAGE       = 4'b0111;

    parameter TOP_EDGE      = 3'd2;
    parameter LEFT_EDGE    = 3'd2;
    parameter BOTTOM_EDGE    = 3'd6;
    parameter RIGHT_EDGE   = 3'd6;

    reg [2:0] current_state, next_state;
    reg [5:0] counter;
    reg [2:0] pos_x, pos_y;
    reg [7:0] max_val, min_val;
    reg [11:0] sum_val;
    reg [7:0] ImageBuffer [63:0];
    reg [5:0] pixel_idx [0:15];

    // 狀態邏輯
    always @(posedge clk) begin
        if (rst)
            current_state <= READ;
        else
            current_state <= next_state;
    end

    // 下一狀態邏輯
    always @(*) begin
        case (current_state)
            READ: 
                next_state = (IROM_A == FINAL_ADDR) ? LOAD_WAIT : READ;
            LOAD_WAIT: 
                next_state = IDLE;
            IDLE: begin
                if (cmd_valid && cmd != WRITE_CMD)
                    next_state = OPERATIONS;
                else if (cmd_valid)
                    next_state = WRITE;
                else
                    next_state = IDLE;
            end
            OPERATIONS: 
                next_state = IDLE;
            WRITE: 
                next_state = (IRAM_A == FINAL_ADDR) ? OUT_WAIT : WRITE;
            OUT_WAIT: 
                next_state = DONE;
            DONE: 
                next_state = DONE;
            default: 
                next_state = IDLE;
        endcase
    end

    // 控制信號
    always @(*) begin
        IROM_rd = 0;
        IRAM_ceb = 0;
        IRAM_web = 1;
        busy = 0;
        done = 0;
        
        case (current_state)
            READ, LOAD_WAIT: begin
                IROM_rd = 1;
                busy = 1;
            end
            IDLE: begin
                // 不需要處理
            end
            OPERATIONS: begin
                busy = 1;
            end
            WRITE, OUT_WAIT: begin
                IRAM_ceb = 1;
                IRAM_web = 0;
                busy = 1;
            end
            DONE: begin
                done = 1;
            end
        endcase
    end

    // IROM地址計數器
    always @(posedge clk) begin
        if (rst)
            IROM_A <= 0;
        else if (current_state == READ && IROM_rd && IROM_A < FINAL_ADDR)
            IROM_A <= IROM_A + 1;
    end

    // IROM數據讀取
    always @(posedge clk) begin
        if (current_state == READ && IROM_rd)
            ImageBuffer[IROM_A] <= IROM_Q;
    end

    // IRAM計數器
    always @(posedge clk) begin
        if (rst)
            counter <= 0;
        else if (current_state == WRITE && IRAM_ceb && counter != FINAL_ADDR)
            counter <= counter + 1;
        else if (current_state != WRITE)
            counter <= 0;
    end

    // IRAM地址設置
    always @(posedge clk) begin
        IRAM_A <= counter;
    end

    // 移動
    always @(posedge clk) begin
        if (rst) begin
            pos_x <= 4;
            pos_y <= 4;
        end else if (current_state == OPERATIONS) begin
            case (cmd)
                UP_CMD:    if (pos_y > TOP_EDGE)    pos_y <= pos_y - 1;
                DOWN_CMD:  if (pos_y < BOTTOM_EDGE)  pos_y <= pos_y + 1;
                LEFT_CMD:  if (pos_x > LEFT_EDGE)  pos_x <= pos_x - 1;
                RIGHT_CMD: if (pos_x < RIGHT_EDGE) pos_x <= pos_x + 1;
            endcase
        end
    end

    // 計算4x4區域的像素索引
    integer row, col, idx;
    always @(*) begin
        idx = 0;
        for (row = 0; row < 4; row = row + 1) begin
            for (col = 0; col < 4; col = col + 1) begin
                pixel_idx[idx] = (pos_y + row - 2) * 8 + (pos_x + col - 2);
                idx = idx + 1;
            end
        end
    end

    // 計算最大值、最小值和平均值
    integer i;
    always @(*) begin
        max_val = ImageBuffer[pixel_idx[0]];
        min_val = ImageBuffer[pixel_idx[0]];
        sum_val = 0;
        
        for (i = 0; i < 16; i = i + 1) begin
            sum_val = sum_val + ImageBuffer[pixel_idx[i]];
                        
            if (ImageBuffer[pixel_idx[i]] > max_val) // 尋找最大值
                max_val = ImageBuffer[pixel_idx[i]];
                
            if (ImageBuffer[pixel_idx[i]] < min_val) // 尋找最小值
                min_val = ImageBuffer[pixel_idx[i]];
        end
    end

    // 輸出邏輯和像素更新
    always @(posedge clk) begin
        case (current_state)
            READ, LOAD_WAIT: begin
                if (IROM_rd)
                    ImageBuffer[IROM_A] <= IROM_Q;
            end
            
            OPERATIONS: begin
                case (cmd)
                    MAX: begin
                        for (i = 0; i < 16; i = i + 1)
                            ImageBuffer[pixel_idx[i]] <= max_val;
                    end
                    
                    MIN: begin
                        for (i = 0; i < 16; i = i + 1)
                            ImageBuffer[pixel_idx[i]] <= min_val;
                    end
                    
                    AVERAGE: begin
                        for (i = 0; i < 16; i = i + 1)
                            ImageBuffer[pixel_idx[i]] <= sum_val[9:4]; // 除以16取平均值
                    end
                endcase
            end
            
            WRITE, OUT_WAIT: begin
                if (IRAM_ceb && !IRAM_web)
                    IRAM_D <= ImageBuffer[counter];
            end
        endcase
    end

endmodule
