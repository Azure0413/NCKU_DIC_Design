`include "Comparator2.v"

module MedianFinder_3num(
    input  [3:0]    num1, 
    input  [3:0]    num2, 
    input  [3:0]    num3,  
    output [3:0]    median  
);
    ///////////////////////////////
    //	Write Your Design Here ~ //
    ///////////////////////////////

    wire [3:0] min1, max1; // num1 和 num2 的 min/max
    wire [3:0] min2, max2; // (num1, num2) 中較大者與 num3 的 min/max
    wire [3:0] min3, max3; // (min1, min2) 中的 min/max

    // 第一次比較 num1 和 num2
    Comparator2 cmp1 (
        .A(num1),
        .B(num2),
        .min(min1),
        .max(max1)
    );

    // 第二次比較 max1 和 num3
    Comparator2 cmp2 (
        .A(max1),
        .B(num3),
        .min(min2),
        .max(max2)
    );

    // 第三次比較 min1 和 min2
    Comparator2 cmp3 (
        .A(min1),
        .B(min2),
        .min(min3),
        .max(max3)
    );

    // max3 即為中位數
    assign median = max3;

endmodule