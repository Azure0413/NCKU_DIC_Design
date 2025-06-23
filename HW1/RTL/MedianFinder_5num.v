`include "MedianFinder_3num.v"  

module MedianFinder_5num(
    input  [3:0]    num1, 
    input  [3:0]    num2, 
    input  [3:0]    num3, 
    input  [3:0]    num4, 
    input  [3:0]    num5,  
    output [3:0]    median  
);

	///////////////////////////////
	//	Write Your Design Here ~ //
	///////////////////////////////

    wire [3:0] min1, max1; // num1 和 num2 的 min/max
    wire [3:0] min2, max2; // num3 和 num4 的 min/max
    wire [3:0] min3, max3; // min1 和 min2 的 min/max
    wire [3:0] min4, max4; // max1 和 max2 的 min/max

    // 第一次比較 num1 和 num2
    Comparator2 cmp1 (
        .A(num1),
        .B(num2),
        .min(min1),
        .max(max1)
    );

    // 第二次比較 num3 和 num4
    Comparator2 cmp2 (
        .A(num3),
        .B(num4),
        .min(min2),
        .max(max2)
    );

    // 第三次比較 min1 和 min2，確保挑出較小值
    Comparator2 cmp3 (
        .A(min1),
        .B(min2),
        .min(min3),
        .max(max3) // max3 即為四個數字中的第二小數字
    );

    // 第四次比較 max1 和 max2，確保挑出較大值
    Comparator2 cmp4 (
        .A(max1),
        .B(max2),
        .min(min4), // min4 即為四個數字中的第二大數字
        .max(max4)
    );

    // 使用 MedianFinder_3num 找出中位數
    MedianFinder_3num median3 (
        .num1(max3),
        .num2(min4),
        .num3(num5),
        .median(median)
    );

endmodule

