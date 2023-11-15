module eth_udp_loop(
    input              sys_rst_n    , //系统复位信号，低电平有效 
    //以太网RGMII接口    
    input              eth_rxc      , //RGMII接收数据时钟
    input              eth_rx_ctl   , //RGMII输入数据有效信号
    input       [3:0]  eth_rxd      , //RGMII输入数据
    input              touch_key    , //按键控制数据开始发送
    output             eth_txc      , //RGMII发送数据时钟    
    output             eth_tx_ctl   , //RGMII输出数据有效信号
    output      [3:0]  eth_txd      , //RGMII输出数据
    inout              led          , //led电平翻转
    output             eth_rst_n      , //以太网芯片复位信号，低电平有效
    
    input              udp_tx_start_en,  //以太网开始发送信号   
    input  [31:0]      tx_data        ,  //以太网待发送数据     
    input  [15:0]      tx_byte_num    ,  //以太网发送的有效字节数 单位:byte 
    output             udp_tx_done    ,  //UDP发送完成信号  
    output             gmii_tx_clk    ,  //GMII发送时钟
    output             tx_req         ,  //读数据请求信号    
    output             gmii_rx_clk       //GMII接收时钟 
    );

//parameter define
//开发板MAC地址 00-11-22-33-44-55
parameter  BOARD_MAC = 48'h00_11_22_33_44_55;     
//开发板IP地址 192.168.1.10
parameter  BOARD_IP  = {8'd192,8'd168,8'd1,8'd10};  
//目的MAC地址 ff_ff_ff_ff_ff_ff
parameter  DES_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//目的IP地址 192.168.1.102     
parameter  DES_IP    = {8'd192,8'd168,8'd1,8'd102};  

//wire define
              
wire          gmii_rx_dv ; //GMII接收数据有效信号
wire  [7:0]   gmii_rxd   ; //GMII接收数据

wire          gmii_tx_en ; //GMII发送数据使能信号
wire  [7:0]   gmii_txd   ; //GMII发送数据     
   

wire          udp_gmii_tx_en; //UDP GMII输出数据有效信号 
wire  [7:0]   udp_gmii_txd  ; //UDP GMII输出数据

//*****************************************************
//**                    main code
//*****************************************************

//assign tx_start_en = rec_pkt_done;


assign eth_rst_n = sys_rst_n;

//PLL
//gmii_pll u_gmii_pll(
//        .lock(locked), //output lock
//        .clkout0(clk_125m), //output 125MHz
//        .clkout1(phy_clk), //output 25MHz
//        .clkin(sys_clk), //input clkin
//        .reset(~sys_rst_n),
//        .clkfb(clkfb) //input clkfb
//    );

//GMII接口转RGMII接口
gmii_to_rgmii 
    u_gmii_to_rgmii(
    .gmii_rx_clk   (gmii_rx_clk ),
    .gmii_rx_dv    (gmii_rx_dv  ),
    .gmii_rxd      (gmii_rxd    ),
    .gmii_tx_clk   (gmii_tx_clk ),
    .gmii_tx_en    (gmii_tx_en  ),
    .gmii_txd      (gmii_txd    ),
    
    .rgmii_rxc     (eth_rxc     ),
    .rgmii_rx_ctl  (eth_rx_ctl  ),
    .rgmii_rxd     (eth_rxd     ),
    .rgmii_txc     (eth_txc     ),
    .rgmii_tx_ctl  (eth_tx_ctl  ),
    .rgmii_txd     (eth_txd     )
    );

//UDP通信
wire [31:0] data_buf;
wire [15:0] data_num_buf;

//assign  data_buf = 32'h61;
//assign  data_num_buf = 16'd4;

assign gmii_tx_en = udp_gmii_tx_en;
assign gmii_txd = udp_gmii_txd;

wire start;
assign  start = udp_tx_start_en & tx_start_en;

udp                                             
   #(
    .BOARD_MAC     (BOARD_MAC),      //参数例化
    .BOARD_IP      (BOARD_IP ),
    .DES_MAC       (DES_MAC  ),
    .DES_IP        (DES_IP   )
    )
   u_udp(
    .rst_n         (sys_rst_n   ),  
    
    .gmii_rx_clk   (gmii_rx_clk ),           
    .gmii_rx_dv    (gmii_rx_dv  ),         
    .gmii_rxd      (gmii_rxd    ),                   
    .gmii_tx_clk   (gmii_tx_clk ), 
    .gmii_tx_en    (udp_gmii_tx_en),         
    .gmii_txd      (udp_gmii_txd),  

    .rec_pkt_done  (rec_pkt_done),    
    .rec_en        (rec_en      ),     
    .rec_data      (rec_data    ),         
    .rec_byte_num  (rec_byte_num),      
    .tx_start_en   (udp_tx_start_en),        
    .tx_data       (tx_data),              //tx_data
    .tx_byte_num   (tx_byte_num),          //tx_byte_num
    .des_mac       (DES_MAC     ),
    .des_ip        (DES_IP      ),    
    .tx_done       (udp_tx_done ),        
    .tx_req        (tx_req      )           
    ); 


udp_ctrl u_udp_ctrl(
    .clk            (gmii_rx_clk), //输入时钟   
    .rst_n          (sys_rst_n), //复位信号，低电平有效
    
    .touch_key      (touch_key), //触摸按键,用于触发开发板发出ARP请求
    .tx_start_en    (tx_start_en), //UDP发送使能信号
    .led             (led)
);

//同步FIFO
//sync_fifo_2048x32b u_sync_fifo_2048x32b(
//		.Data(data_buf), //input [31:0] Data
//		.Clk(gmii_rx_clk), //input Clk
//		.WrEn(1'b1), //input udp发送完成信号		
//        .RdEn(tx_req), //读数据请求
//		.Reset(~sys_rst_n), //input Reset
//		.Q(tx_data), //output [31:0] Q
//		.Empty(), //output Empty
//		.Full() //output Full
//	);

endmodule