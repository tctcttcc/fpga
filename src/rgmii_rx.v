module rgmii_rx(
    //以太网RGMII接口
    input              rgmii_rxc   , //RGMII接收时钟
    input              rgmii_rx_ctl, //RGMII接收数据控制信号
    input       [3:0]  rgmii_rxd   , //RGMII接收数据    

    //以太网GMII接口
    output             gmii_rx_clk , //GMII接收时钟
    output             gmii_rx_dv  , //GMII接收数据有效信号
    output      [7:0]  gmii_rxd      //GMII接收数据   
    );

//wire define

wire  [1:0]  gmii_rxdv_t;        //两位GMII接收有效信号 

assign gmii_rx_dv = gmii_rxdv_t[0] & gmii_rxdv_t[1];

//*****************************************************
//**                    main code
//*****************************************************

//输入双沿采样寄存器

rgmii_pll u_rmgii_pll(
        .clkout0(gmii_rx_clk), //output clkout0
        .clkin(rgmii_rxc), //input clkin
        .clkfb(gmii_rx_clk) //input clkfb
    );

IDDR #(
    .Q0_INIT    (1'b0),  //默认初始值为0
    .Q1_INIT    (1'b0)
) u_iddr_rx_ctl(
    .Q0       (gmii_rxdv_t[0]),         // 1-bit output for positive edge of clock
    .Q1       (gmii_rxdv_t[1]),         // 1-bit output for negative edge of clock
    .CLK      (gmii_rx_clk),        // 1-bit clock input
    .D        (rgmii_rx_ctl)            // 1-bit DDR data input
);

//rgmii_rxd输入延时与双沿采样,四个数据循环五次

genvar i;
generate for (i=0; i<4; i=i+1)
    begin : rxdata_bus
        //输入双沿采样寄存器
        IDDR #(
            .Q0_INIT    (1'b0),  //默认初始值为0
            .Q1_INIT    (1'b0)
        ) u_iddr_rxd (
            .Q0       (gmii_rxd[i]),            // 1-bit output for positive edge of clock
            .Q1       (gmii_rxd[4+i]),          // 1-bit output for negative edge of clock
            .CLK      (gmii_rx_clk),       // 1-bit clock input rgmii_rxc_bufio
            .D        (rgmii_rxd[i])            // 1-bit DDR data input
        );
    end
endgenerate

endmodule










