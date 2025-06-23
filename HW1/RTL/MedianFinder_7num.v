`include "MedianFinder_5num.v"

module MedianFinder_7num(
    input  [3:0] num1, 
    input  [3:0] num2, 
    input  [3:0] num3, 
    input  [3:0] num4, 
    input  [3:0] num5,  
    input  [3:0] num6,  
    input  [3:0] num7,  
    output [3:0] median  
);

	///////////////////////////////
	//	Write Your Design Here ~ //
	///////////////////////////////

    // step1: 先比較最小值
     Comparator2 cmin_1(
        .A(num1),
        .B(num2),
        .min(),
        .max()
    );

    Comparator2 cmin_2(
        .A(cmin_1.min),
        .B(num3),
        .min(),
        .max()
    );

    Comparator2 cmin_3(
        .A(cmin_2.min),
        .B(num4),
        .min(),
        .max()
    );

    Comparator2 cmin_4(
        .A(cmin_3.min),
        .B(num5),
        .min(),
        .max()
    );

    Comparator2 cmin_5(
        .A(cmin_4.min),
        .B(num6),
        .min(),
        .max()
    );

    Comparator2 cmin_6(
        .A(cmin_5.min),
        .B(num7),
        .min(),
        .max()
    );

    // step2: 再比較最大值
    Comparator2 cmax_1(
        .A(cmin_5.max),
        .B(cmin_6.max),
        .min(),
        .max()
    );

    Comparator2 cmax_2(
        .A(cmax_1.max),
        .B(cmin_4.max),
        .min(),
        .max()
    );

    Comparator2 cmax_3(
        .A(cmax_2.max),
        .B(cmin_3.max),
        .min(),
        .max()
    );

    Comparator2 cmax_4(
        .A(cmax_3.max),
        .B(cmin_2.max),
        .min(),
        .max()
    );

    Comparator2 cmax_5(
        .A(cmax_4.max),
        .B(cmin_1.max),
        .min(),
        .max()
    );

    // step3: 去頭尾可比較剩下的5個數值 => 用 medianfinder_5
    MedianFinder_5num median_5(
		.num1(cmax_5.min),
		.num2(cmax_4.min),
		.num3(cmax_3.min),
		.num4(cmax_2.min),
		.num5(cmax_1.min),
		.median()
	);

    assign median = median_5.median;
    
endmodule