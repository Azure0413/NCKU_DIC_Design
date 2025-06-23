module MCH (
    input               clk,
    input               reset,
    input       [ 7:0]  X,
    input       [ 7:0]  Y,
    output              Done,
    output      [16:0]  area
);

    // registers for coordinates
    reg [7:0] px [0:19];
    reg [7:0] py [0:19];

    reg [4:0] load_counter;  
    reg [4:0] anchor_idx;

    // registers for bubble sorting - 簡化邏輯
    reg [4:0] pass_idx, i_idx;
    reg [1:0] swapped_anchor;
    reg       sorting_done;
    reg [7:0] tmp_x, tmp_y;
    reg       swap_phase;

    // registers for stack
    reg [4:0] stack [0:19]; 
    reg [4:0] top;
    reg [4:0] scan_idx;

    // registers for area calculation
    reg signed [31:0] sum;
    reg        [4:0] area_idx;
    wire       [4:0] j;

    function signed [18:0] cross;
        input [7:0] ax, ay, bx, by, cx, cy;
        begin
            cross = ($signed({1'b0,bx})-$signed({1'b0,ax}))*
                    ($signed({1'b0,cy})-$signed({1'b0,ay})) -
                    ($signed({1'b0,by})-$signed({1'b0,ay}))*
                    ($signed({1'b0,cx})-$signed({1'b0,ax}));
        end
    endfunction

    // state
    reg [2:0] cur_state;
    reg [2:0] next_state;

    // stage parameters
    parameter LOAD          = 3'b000;
    parameter SORT          = 3'b001;
    parameter LOWER         = 3'b010;
    parameter AREA          = 3'b011;
    parameter DONE          = 3'b100;

    // state register
    always @(posedge clk) begin
        if (reset)
            cur_state <= LOAD;
        else
            cur_state <= next_state;
    end

    // 修正的next state logic
    always @(*) begin 
        case (cur_state)
            LOAD: begin
                next_state = (load_counter == 5'd19) ? SORT : LOAD;
            end
            SORT: begin
                // 修正：當完成所有pass且沒有更多swap時結束
                next_state = sorting_done ? LOWER : SORT;
            end
            LOWER: begin
                next_state = (scan_idx == 5'd20) ? AREA : LOWER;
            end
            AREA: begin
                next_state = (area_idx == top - 1) ? DONE : AREA;
            end
            DONE: begin
                next_state = LOAD;
            end
            default: next_state = LOAD;
        endcase
    end

    // load counter
    always @(posedge clk) begin
        if (reset)
            load_counter <= 5'd0;
        else if (cur_state == LOAD)
            load_counter <= load_counter + 5'd1;
        else if (cur_state == DONE)
            load_counter <= 5'd0;
        else
            load_counter <= load_counter;
    end

    // anchor finding
    always @(posedge clk) begin
        if (reset)
            anchor_idx   <= 5'b0;
        else if (cur_state == LOAD) begin
                if ((Y < py[anchor_idx]) || (Y == py[anchor_idx] && X < px[anchor_idx]))
                    anchor_idx <= load_counter;
                else
                    anchor_idx <= anchor_idx;
        end else if (cur_state == DONE)
            anchor_idx   <= 5'b0;
        else begin
            anchor_idx   <= anchor_idx;
        end
    end

    wire signed [18:0] cp = cross(px[0], py[0], px[i_idx], py[i_idx], px[i_idx+1], py[i_idx+1]);
    wire swap_needed = (cp < 0) || (cp == 0 && 
        (($signed({1'b0,px[i_idx]}) > $signed({1'b0,px[i_idx+1]})) ||
         ($signed({1'b0,px[i_idx]}) == $signed({1'b0,px[i_idx+1]}) && 
          $signed({1'b0,py[i_idx]}) > $signed({1'b0,py[i_idx+1]})))
    );

    integer i;
    always @(posedge clk) begin
        if (reset || cur_state == DONE) begin
            for(i = 0; i < 20; i = i + 1) begin
                px[i] <= 8'd0;
                py[i] <= 8'd0;
            end
            pass_idx <= 5'd19;
            i_idx    <= 5'd1;
            swapped_anchor <= 2'b0;
            sorting_done <= 1'b0;
            swap_phase <= 1'b0;
            tmp_x <= 8'd0;
            tmp_y <= 8'd0;
        end else if (cur_state == LOAD) begin
            px[load_counter] <= X;
            py[load_counter] <= Y;
        end else if (cur_state == SORT && swapped_anchor == 2'd0) begin
            // 交換anchor到位置0
            swapped_anchor <= 2'd1;
            tmp_x <= px[0];
            tmp_y <= py[0];
            px[0] <= px[anchor_idx];
            py[0] <= py[anchor_idx];
        end else if (cur_state == SORT && swapped_anchor == 2'd1) begin
            swapped_anchor <= 2'd2;
            px[anchor_idx] <= tmp_x;
            py[anchor_idx] <= tmp_y;
        end else if (cur_state == SORT && swapped_anchor == 2'd2) begin
            if (!swap_phase) begin
                // 檢查是否需要交換
                if (i_idx < pass_idx && swap_needed) begin
                    swap_phase <= 1'b1;
                    tmp_x <= px[i_idx];
                    tmp_y <= py[i_idx];
                    px[i_idx] <= px[i_idx+1];
                    py[i_idx] <= py[i_idx+1];
                end else begin
                    // 移動到下一個比較
                    if (i_idx >= pass_idx) begin
                        // 完成一個pass
                        if (pass_idx <= 5'd2) begin
                            sorting_done <= 1'b1;
                        end else begin
                            pass_idx <= pass_idx - 1'b1;
                            i_idx <= 5'd1;
                        end
                    end else begin
                        i_idx <= i_idx + 1'b1;
                    end
                end
            end else begin
                // 完成交換
                px[i_idx+1] <= tmp_x;
                py[i_idx+1] <= tmp_y;
                swap_phase <= 1'b0;
                i_idx <= i_idx + 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset || cur_state == DONE) begin
            top <= 2;                       
            stack[0] <= 5'd0;
            stack[1] <= 5'd1;
            scan_idx <= 5'd2;
            for(i = 2; i < 20; i = i + 1) begin
                stack[i] <= 5'd0;
            end
        end else if (cur_state == LOWER) begin
            if (scan_idx < 5'd20) begin
                if (top >= 2 && cross(px[stack[top-2]], py[stack[top-2]], 
                                     px[stack[top-1]], py[stack[top-1]], 
                                     px[scan_idx], py[scan_idx]) <= 0) begin
                    top <= top - 1;              
                end else begin
                    stack[top] <= scan_idx;      
                    top        <= top + 1;
                    scan_idx   <= scan_idx + 1;
                end
            end
        end
    end

    assign j = (area_idx == top-1) ? 5'd0 : area_idx + 5'd1;

    // 直接使用乘法運算符，讓synthesizer優化
    always @(posedge clk) begin
        if (reset || cur_state == DONE) begin
            sum <= 32'sd0;
        end else if (cur_state == AREA) begin
            sum <= sum + $signed({1'b0, px[stack[area_idx]]}) * 
                         $signed({1'b0, py[stack[j]]}) -
                         $signed({1'b0, px[stack[j]]}) * 
                         $signed({1'b0, py[stack[area_idx]]});
        end else begin
            sum <= sum;
        end
    end

    // Area index
    always @(posedge clk) begin
        if (reset || cur_state == DONE) begin
            area_idx <= 5'd0;
        end else if (cur_state == AREA) begin
            area_idx <= area_idx + 1'b1;
        end else begin
            area_idx <= area_idx;
        end
    end
    
    assign area = sum[31] ? -sum[16:0] : sum[16:0];  // 取絕對值並輸出17位
    assign Done = (cur_state == DONE);

endmodule
