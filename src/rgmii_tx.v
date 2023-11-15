module rgmii_tx(
    //GMII发送端口
    input              gmii_tx_clk      , //GMII发送时钟    
    input              gmii_tx_en       , //GMII输出数据有效信号
    input       [7:0]  gmii_txd         , //GMII输出数据        
    input              gmii_tx_clk_deg  , //GMII发送时钟相位偏移45度
    //RGMII发送端口
    output             rgmii_txc        , //RGMII发送数据时钟    
    output             rgmii_tx_ctl     , //RGMII输出数据有效信号
    output      [3:0]  rgmii_txd          //RGMII输出数据     
    );

//*****************************************************
//**                    main code
//*****************************************************
assign rgmii_txc = gmii_tx_clk;

//输出双沿采样寄存器 (rgmii_tx_ctl)
ODDR #(
    .INIT          (1'b0),  //默认初始值为0
    .TXCLK_POL     (1'b0)   //控制TX发送 1'b0下降沿,(不用管)
) ODDR_inst(
    .Q0            (rgmii_tx_ctl), // 1-bit DDR output
    .CLK           (gmii_tx_clk),  // 1-bit clock input
    .D0            (gmii_tx_en),   // 1-bit data input (positive edge)
    .D1            (gmii_tx_en)   // 1-bit data input (negative edge)
);

genvar i;
generate for (i=0; i<4; i=i+1)
    begin : txdata_bus
        //输出双沿采样寄存器 (rgmii_txd)
        ODDR #(
            .INIT          (1'b0),  //默认初始值为0
            .TXCLK_POL     (1'b0)
        )ODDR_inst (
            .Q0            (rgmii_txd[i]), // 1-bit DDR output
            .CLK           (gmii_tx_clk),  // 1-bit clock input
            .D0            (gmii_txd[i]),  // 1-bit data input (positive edge)
            .D1            (gmii_txd[4+i])// 1-bit data input (negative edge)
        );
    end
endgenerate

endmodule








