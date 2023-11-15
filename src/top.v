module top(
	input                       clk,
	input                       sys_rst_n,
	inout                       cmos_scl,          //cmos i2c clock
	inout                       cmos_sda,          //cmos i2c data
	input                       cmos_vsync,        //cmos vsync
	input                       cmos_href,         //cmos hsync refrence,data valid
	input                       cmos_pclk,         //cmos pxiel clock
    output                      cmos_xclk,         //cmos externl clock 
	input   [7:0]               cmos_db,           //cmos data
	output                      cmos_rst_n,        //cmos reset 
	output                      cmos_pwdn,         //cmos power down
	output  sys_run,cam_run,rst_led,

	output[2:0]					i2c_sel,
	output                      clk_out,

    input                       eth_rxc   , //RGMII接收数据时钟
    input                       eth_rx_ctl, //RGMII输入数据有效信号
    input       [3:0]           eth_rxd   , //RGMII输入数据
    input                       touch_key , //按键控制数据开始发送
    output                      eth_txc   , //RGMII发送数据时钟    
    output                      eth_tx_ctl, //RGMII输出数据有效信号
    output      [3:0]           eth_txd   , //RGMII输出数据
    output                      phy_clk   , //PHY芯片的时钟信号25MHz        
    inout                       led       , //led电平翻转
    output                      eth_rst_n , //以太网芯片复位信号，低电平有效 
    
    output       [14:0]         ddr_addr       ,       //ROW_WIDTH=15
	output       [2:0]          ddr_bank       ,       //BANK_WIDTH=3
	output                      ddr_cs         ,
	output                      ddr_ras        ,
	output                      ddr_cas        ,
	output                      ddr_we         ,
	output                      ddr_ck         ,
	output                      ddr_ck_n       ,
	output                      ddr_cke        ,  
	output                      ddr_odt        ,
	output                      ddr_reset_n    ,
	output      [3:0]           ddr_dm         ,         //DM_WIDTH=2
	inout       [15:0]          ddr_dq         ,         //DQ_WIDTH=16
	inout       [3:0]           ddr_dqs        ,        //DQS_WIDTH=2
	inout       [3:0]           ddr_dqs_n       //DQS_WIDTH=2
);

assign i2c_sel = 'b101;
assign clk_out = clk;

//parameter define
//开发板MAC地址 00-11-22-33-44-55
parameter  BOARD_MAC = 48'h00_11_22_33_44_55;     
//开发板IP地址 192.168.1.10
parameter  BOARD_IP  = {8'd192,8'd168,8'd1,8'd10};  
//目的MAC地址 ff_ff_ff_ff_ff_ff
parameter  DES_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//目的IP地址 192.168.1.102     
parameter  DES_IP    = {8'd192,8'd168,8'd1,8'd102};  

parameter  H_PIXEL    = 30'd640       ;  //CMOS水平方向像素个数
parameter  V_PIXEL    = 30'd479       ;  //CMOS垂直方向像素个数

wire                            clk_50m;         //video pixel clock
wire[15:0]                      cmos_16bit_data;
wire[15:0] 						write_data;
wire                            cmos_frame_vsync;   //场同步有效信号
wire                            cmos_frame_valid;   //数据有效信号

wire[9:0]                       lut_index;
wire[31:0]                      lut_data;

assign cmos_xclk = cmos_clk;    //摄像头时钟，固定值24MHz
assign cmos_pwdn = 1'b0;
assign cmos_rst_n = 1'b1;
assign rst_led = rst_n;
assign write_data = {cmos_16bit_data[4:0],cmos_16bit_data[10:5],cmos_16bit_data[15:11]};

//*****************************
wire    transfer_flag;
assign  transfer_flag = 1'b1;       //时钟允许发送

wire            transfer_flag   ;   //图像开始传输标志,0:开始传输 1:停止传输
wire            eth_rx_clk      ;   //以太网接收时钟
wire            udp_tx_start_en ;   //以太网开始发送信号
wire   [15:0]   udp_tx_byte_num ;   //以太网发送的有效字节数
wire   [31:0]   udp_tx_data     ;   //以太网发送的数据    

wire            udp_tx_req      ;   //以太网发送请求数据信号
wire            udp_tx_done     ;   //以太网发送完成信号
wire            wr_vsync        ;
wire            rd_vsync        ;
//*****************************
wire udp_tx_start_en_buf;
wire [31:0] udp_tx_data_buf;
assign  udp_tx_data_buf = (eth_tx_data==32'h5a_a5_00_00 && i_config_end) ? 32'h53_5a_48_59 : 
(eth_tx_data == 32'h53_5a_48_59 && i_config_end) ? (32'h00_0c_60_09) : (eth_tx_data == 32'h00_0c_60_09 && i_config_end) ? 
{16'h00_02,eth_tx_data[15:0]}:eth_tx_data;
//assign  udp_tx_start_en_buf = (udp_tx_data==32'h0) ? 1'b0 : udp_tx_start_en;

wire            i_config_end    ;   //图像格式包发送完成
wire            eth_tx_start    ;   //以太网开始发送信号
wire            eth_tx_start_i  ;   //以太网开始发送信号(图像)
wire            eth_tx_start_f  ;   //以太网开始发送信号(格式)
wire    [31:0]  eth_tx_data     ;   //以太网发送的数据
wire    [31:0]  eth_tx_data_f   ;   //以太网发送的数据(格式)
wire    [31:0]  eth_tx_data_i   ;   //以太网发送的数据(图像)
wire    [15:0]  eth_tx_data_num ;   //以太网单包发送的有效字节数
wire    [15:0]  eth_tx_data_num_i;  //以太网单包发送的有效字节数(图像)
wire    [15:0]  eth_tx_data_num_f;  //以太网单包发送的有效字节数(格式)
//****************
wire    memory_clk;
wire    pll_stop;
wire    pll_lock;
wire    c3_rst0 ;
wire    rd_vsync;
reg [5:0] vs_running;
assign sys_run = vs_running[5];
always@(posedge cmos_vsync)         //原本是lcd_vs
	vs_running <= vs_running + 6'd1;

reg [5:0] cam_running;
assign cam_run = cam_running[5];
always@(posedge cmos_vsync)
	cam_running <= cam_running + 6'd1;

wire    init_calib_complete;
wire    rst_n   ;
wire    sys_init_done;
assign  rst_n = sys_rst_n & !c3_rst0 & locked1 & locked2 & pll_lock & locked;
assign  sys_init_done = !c3_rst0 & cfg_done & init_calib_complete;
// generate rgb_lcd 
wire    locked1;
wire    locked2;
wire    cfg_done;
sys_pll sys_pll_m0(
	.clkin                     (clk                      ),
	.clkout0                   (clk_50m 	              ),
    .lock                      (locked1                 )
	);
cmos_pll cmos_pll_m0(
	.clkin                     (clk                      ),
	.clkout0                   (cmos_clk 	             ),
    .lock                      (locked2                  )
	);

mem_clk u_mem_clk(
        .lock(pll_lock), //output lock
        .clkout0(memory_clk), //output clkout0
        .clkin(clk), //input clkin
        .enclk0(pll_stop) //input enclk0
    );

wire    clk_125m;
wire    clkfb   ;
wire    locked  ;
gmii_pll u_gmii_pll(
        .lock(locked), //output lock
        .clkout0(clk_125m), //output 125MHz
        .clkout1(phy_clk), //output 25MHz
        .clkin(clk), //input clkin
        .reset(~sys_rst_n),
        .clkfb(clkfb) //input clkfb
    );

wire    cfg_done    ;
wire    cfg_end     ;

wire    ov5640_wr_en;
wire    [15:0]  image_data_tx;

ov5640_top u_ov5640_top(
    .clk_50m         (clk_50m),
    .sys_rst         (c3_rst0),
    .cmos_scl        (cmos_scl),
    .cmos_sda        (cmos_sda),
    .cmos_pclk       (cmos_pclk),
    .cmos_href       (cmos_href),
    .cmos_vsync      (cmos_vsync),
    .cmos_db         (cmos_db), 
    .ov5640_wr_en    (ov5640_wr_en),
    .cmos_16bit_data (cmos_16bit_data),
    .wr_vsync        (wr_vsync  ),
    .cfg_done        (cfg_done  ),
    .sys_init_done   (sys_init_done)
);

wire    gmii_tx_clk;
wire    rd_en;

assign  eth_tx_start    = eth_tx_start_i;
assign  eth_tx_data     = eth_tx_data_i;
assign  eth_tx_data_num = eth_tx_data_num_i;

//上位机配置模块
image_format  image_format_inst
(
    .sys_clk            (gmii_tx_clk            ),  //系统时钟
    .sys_rst_n          (rst_n              ),  //系统复位，低电平有效
    .eth_tx_req         (udp_tx_req&&(~i_config_end)),  //以太网数据请求信号
    .eth_tx_done        (udp_tx_done            ),  //单包以太网数据发送完成信号

    .eth_tx_start       (eth_tx_start_f         ),  //以太网发送数据开始信号
    .eth_tx_data        (eth_tx_data_f          ),  //以太网发送数据
    .i_config_end       (i_config_end           ),  //图像格式包发送完成
    .eth_tx_data_num    (eth_tx_data_num_f      )   //以太网单包数据有效字节数
);
//------------- image_data_inst -------------

//图像数据封装模块  
image_data
#(
    .H_PIXEL            (H_PIXEL            ),  //图像水平方向像素个数
    .V_PIXEL            (V_PIXEL            )   //图像竖直方向像素个数
)
image_data_inst
(
    .sys_clk            (gmii_tx_clk        ),  //系统时钟,频率25MHz
    .sys_rst_n          (rst_n),  //复位信号,低电平有效
    .image_data         (image_data_tx      ),  //自DDR中读取的16位图像数据
    .eth_tx_req         (udp_tx_req         ),  //以太网发送数据请求信号
    .eth_tx_done        (udp_tx_done        ),  //以太网发送数据完成信号

    .rd_vsync           (rd_vsync           ),
    .data_rd_req_f      (rd_en              ),  //图像数据请求信号 rd_en
    .eth_tx_start       (eth_tx_start_i     ),  //以太网发送数据开始信号
    .eth_tx_data        (eth_tx_data_i      ),  //以太网发送数据
    .eth_tx_data_num    (eth_tx_data_num_i  )   //以太网单包数据有效字节数
);

//以太网顶层模块    
eth_udp_loop  #(
    .BOARD_MAC     (BOARD_MAC),              //参数例化
    .BOARD_IP      (BOARD_IP ),          
    .DES_MAC       (DES_MAC  ),          
    .DES_IP        (DES_IP   )          
    )          
    u_eth_top(          
    .sys_rst_n       (rst_n),           //系统复位信号，低电平有效             
    //以太网RGMII接口             
    .eth_rxc         (eth_rxc   ),           //RGMII接收数据时钟
    .eth_rx_ctl      (eth_rx_ctl),           //RGMII输入数据有效信号
    .eth_rxd         (eth_rxd   ),           //RGMII输入数据
    .eth_txc         (eth_txc   ),           //RGMII发送数据时钟    
    .eth_tx_ctl      (eth_tx_ctl),           //RGMII输出数据有效信号
    .eth_txd         (eth_txd   ),           //RGMII输出数据          
    .eth_rst_n       (eth_rst_n ),           //以太网芯片复位信号，低电平有效 

    .gmii_rx_clk     (gmii_rx_clk),
    .gmii_tx_clk     (gmii_tx_clk),       
    .udp_tx_start_en (eth_tx_start),
    .tx_data         (eth_tx_data),
    .tx_byte_num     (eth_tx_data_num),
    .udp_tx_done     (udp_tx_done),
    .tx_req          (udp_tx_req ),
    .led             (led),
    .touch_key       (touch_key)
    );

//DDR3暂存模块
/*
fifo_ov5640 u_fifo_ov5640(
		.Data(write_data), //input [15:0] Data
		.Reset(~rst_n), //input Reset
		.WrClk(cmos_pclk), //input WrClk
		.RdClk(gmii_tx_clk), //input RdClk
		.WrEn(ov5640_wr_en), //input WrEn
		.RdEn(rd_en), //input RdEn
		.Q(image_data_tx), //output [15:0] Q
		.Empty(), //output Empty
		.Full() //output Full
	);
*/
ddr3_top u_ddr3_top(
    .eth_tx_clk         (gmii_tx_clk),   //以太网发送时钟  
    .cam_pclk           (cmos_pclk),   //像素时钟
    .memory_clk         (memory_clk),
    .rst_n              (sys_rst_n & pll_lock),   //复位信号，低电平有效
    .pll_lock           (pll_lock   ),
    .pll_stop           (pll_stop   ),
    //图像相关信号
    .wr_vsync           (wr_vsync   ),   //帧同步信号cmos_vsync
    .rd_vsync           (rd_vsync   ),
    .img_wr_data        (write_data),   //有效数据
    .wr_en              (ov5640_wr_en),
    .transfer_flag      (),   //图像开始传输标志,1:开始传输 0:停止传输
    //以太网相关信号 
    .rd_en              (rd_en       ),
    .img_rd_data        (image_data_tx),
    .ddr_reset          (c3_rst0    ),
    .init_calib_complete(init_calib_complete),
     //DDR
    .ddr_addr           (ddr_addr)  , //output [13:0] O_ddr_addr//ROW_WIDTH=15
	.ddr_bank           (ddr_bank)  , //output [2:0] O_ddr_ba//BANK_WIDTH=3
	.ddr_cs             (ddr_cs)    , //output O_ddr_cs_n
	.ddr_ras            (ddr_ras)   , //output O_ddr_ras_n
	.ddr_cas            (ddr_cas)   , //output O_ddr_cas_n
	.ddr_we             (ddr_we)    , //output O_ddr_we_n
	.ddr_ck             (ddr_ck)    , //output O_ddr_clk
	.ddr_ck_n           (ddr_ck_n)  , //output O_ddr_clk_n
	.ddr_cke            (ddr_cke)   , //output O_ddr_cke
	.ddr_odt            (ddr_odt)   , //output O_ddr_odt
	.ddr_reset_n        (ddr_reset_n), //output O_ddr_reset_n
	.ddr_dm             (ddr_dm)    , //output [3:0] O_ddr_dqm  //DM_WIDTH=2
	.ddr_dq             (ddr_dq)    , //inout [31:0] IO_ddr_dq  //DQ_WIDTH=16
	.ddr_dqs            (ddr_dqs)   , //inout [3:0] IO_ddr_dqs //DQS_WIDTH=2
	.ddr_dqs_n          (ddr_dqs_n)     //inout [3:0] IO_ddr_dqs_nIDTH=2
);

endmodule

