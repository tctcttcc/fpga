module ddr3_top(
    input                 eth_tx_clk     ,   //以太网发送时钟  
    input                 cam_pclk       ,   //像素时钟
    input                 memory_clk     ,
    input                 rst_n         ,   //复位信号，低电平有效
    input                 pll_lock      ,
    output                pll_stop      ,
    //图像相关信号
    input                 wr_vsync       ,   //帧同步信号cmos_vsync
    input                 rd_vsync       ,
    input        [15:0]   img_wr_data   ,   //有效数据
    input                 wr_en         ,
    input                 transfer_flag  ,   //图像开始传输标志,1:开始传输 0:停止传输
    //以太网相关信号 
    input                 rd_en          ,
    output       [15:0]   img_rd_data    ,
    output                ddr_reset      ,
    output                init_calib_complete,
     //DDR
    output       [14:0]   ddr_addr       ,       //ROW_WIDTH=15
	output       [2:0]    ddr_bank       ,       //BANK_WIDTH=3
	output                ddr_cs         ,
	output                ddr_ras        ,
	output                ddr_cas        ,
	output                ddr_we         ,
	output                ddr_ck         ,
	output                ddr_ck_n       ,
	output                ddr_cke        ,  
	output                ddr_odt        ,
	output                ddr_reset_n    ,
	output      [3:0]     ddr_dm         ,         //DM_WIDTH=2
	inout       [15:0]    ddr_dq         ,         //DQ_WIDTH=16
	inout       [3:0]     ddr_dqs        ,        //DQS_WIDTH=2
	inout       [3:0]     ddr_dqs_n       //DQS_WIDTH=2
);    

reg             img_vsync_d0    ;  //帧有效信号打拍
reg             img_vsync_d1    ;  //帧有效信号打拍
reg             img_vsync_d2    ;
reg             neg_vsync_d0    ;  //帧有效信号下降沿打拍
                                
reg             wr_sw           ;  //用于位拼接的标志
reg    [15:0]   img_data_d0     ;  //有效图像数据打拍

reg             img_vsync_txc_d0;  //以太网发送时钟域下,帧有效信号打拍
reg             img_vsync_txc_d1;  //以太网发送时钟域下,帧有效信号打拍
reg             img_vsync_txc_d2;
reg             tx_busy_flag    ;  //发送忙信号标志

//wire define                   
wire            pos_vsync_t       ;  //帧有效信号上升沿
wire            neg_vsync_t       ;  //帧有效信号下降沿
wire            neg_vsynt_txc_t   ;  //以太网发送时钟域下,帧有效信号下降沿
//wire   [9:0]    fifo_rdusedw    ;  //当前FIFO缓存的个数
//wire            init_calib_complete;
//****************************DDR*************************
wire            dma_clk           ;  //DDR输出时钟用于控制video_fifo
wire            cmd_ready          ;
wire    [2:0]   cmd                ;
wire            cmd_en             ;
wire    [5:0]   app_burst_number   ;
wire    [27:0]  addr               ;
wire            wr_data_rdy        ;
wire            wr_data_en         ;//
wire            wr_data_end        ;//
wire    [127:0] wr_data            ;//256位      
wire    [15:0]  wr_data_mask       ;//16位 
wire            rd_data_valid      ;  
wire            rd_data_end        ;//unused 
wire    [127:0] rd_data            ;//256位   

//*****************************************************
//**                    main code
//*****************************************************

//信号采沿
assign neg_vsync_t = img_vsync_d2 & (~img_vsync_d1);
assign pos_vsync_t = ~img_vsync_d2 & img_vsync_d1;
assign neg_vsynt_txc_t = ~img_vsync_txc_d2 & img_vsync_txc_d1;

//对img_vsync信号延时两个时钟周期,用于采沿
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n) begin
        img_vsync_d0 <= 1'b0;
        img_vsync_d1 <= 1'b0;
        img_vsync_d2 <= 1'b0;
    end
    else begin
        img_vsync_d0 <= wr_vsync;
        img_vsync_d1 <= img_vsync_d0;
        img_vsync_d2 <= img_vsync_d1;
    end
end

//寄存neg_vsync信号
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n) 
        neg_vsync_d0 <= 1'b0;
    else 
        neg_vsync_d0 <= neg_vsync_t;
end    

//以太网发送时钟域下,对img_vsync信号延时两个时钟周期,用于采沿
always @(posedge eth_tx_clk or negedge rst_n) begin
    if(!rst_n) begin
        img_vsync_txc_d0 <= 1'b0;
        img_vsync_txc_d1 <= 1'b0;   
        img_vsync_txc_d2 <= 1'b0;
    end
    else begin
        img_vsync_txc_d0 <= wr_vsync;
        img_vsync_txc_d1 <= img_vsync_txc_d0;
        img_vsync_txc_d2 <= img_vsync_txc_d1;
    end
end

video_frame_buffer u_video_frame_buffer
( 
    .I_rst_n              (init_calib_complete ),//rst_n            ),
    .I_dma_clk            (dma_clk          ),   //sram_clk         ),
`ifdef USE_THREE_FRAME_BUFFER 
    .I_wr_halt            (1'd0             ), //1:halt,  0:no halt
    .I_rd_halt            (1'd0             ), //1:halt,  0:no halt
`endif
    // video data input             
    .I_vin0_clk           (cam_pclk        ),
    .I_vin0_vs_n          (~wr_vsync       ),//只接收负极性
    .I_vin0_de            (wr_en           ),//write enable
    .I_vin0_data          (img_wr_data      ),//16bit
    .O_vin0_fifo_full     (        ),
    // video data output            
    .I_vout0_clk          (eth_tx_clk       ),//发送时钟
    .I_vout0_vs_n         (~rd_vsync        ),//只接收负极性
    .I_vout0_de           (rd_en            ),//发送使能信号
    .O_vout0_den          (        ),
    .O_vout0_data         (img_rd_data      ),//16bit
    .O_vout0_fifo_empty   (),
    // ddr write request
    .I_cmd_ready          (cmd_ready          ),
    .O_cmd                (cmd                ),//0:write;  1:read
    .O_cmd_en             (cmd_en             ),
//    .O_app_burst_number   (app_burst_number   ),//    .O_app_burst_number   (app_burst_number   ),
    .O_addr               (addr               ),//[ADDR_WIDTH-1:0]
    .I_wr_data_rdy        (wr_data_rdy        ),
    .O_wr_data_en         (wr_data_en         ),//
    .O_wr_data_end        (wr_data_end        ),//
    .O_wr_data            (wr_data            ),//[DATA_WIDTH-1:0]
    .O_wr_data_mask       (wr_data_mask       ),
    .I_rd_data_valid      (rd_data_valid      ),
    .I_rd_data_end        (rd_data_end        ),//unused 
    .I_rd_data            (rd_data            ),//[DATA_WIDTH-1:0]
    .I_init_calib_complete(init_calib_complete)
);

DDR3_Memory_Interface_Top DDR3_Memory_Interface_Top_inst(
    .clk                (eth_tx_clk), //input clk
    .pll_stop           (pll_stop), //output pll_stop
    .memory_clk         (memory_clk), //input memory_clk
    .pll_lock           (pll_lock), //input pll_lock
    .rst_n              (rst_n), //input rst_n
    .cmd_ready          (cmd_ready), //output cmd_ready
    .cmd                (cmd), //input [2:0] cmd
    .cmd_en             (cmd_en), //input cmd_en
    .addr               (addr), //input [27:0] addr
    .wr_data_rdy        (wr_data_rdy), //output wr_data_rdy
    .wr_data            (wr_data), //input [255:0] wr_data
    .wr_data_en         (wr_data_en), //input wr_data_en
    .wr_data_end        (wr_data_end), //input wr_data_end
    .wr_data_mask       (wr_data_mask), //input [31:0] wr_data_mask
    .rd_data            (rd_data), //output [255:0] rd_data
    .rd_data_valid      (rd_data_valid), //output rd_data_valid
    .rd_data_end        (rd_data_end), //output rd_data_end
    .sr_req             (1'b0), //input sr_req
    .ref_req            (1'b0), //input ref_req
    .sr_ack             (),     //output sr_ack
    .ref_ack            (),     //output ref_ack
    .init_calib_complete(init_calib_complete), //output init_calib_complete
    .clk_out            (dma_clk), //output clk_out
    .ddr_rst            (ddr_reset), //output ddr_rst
    .burst              (1'b1), //input burst
    .O_ddr_addr         (ddr_addr), //output [13:0] O_ddr_addr
    .O_ddr_ba           (ddr_bank), //output [2:0] O_ddr_ba
    .O_ddr_cs_n         (ddr_cs), //output O_ddr_cs_n
    .O_ddr_ras_n        (ddr_ras), //output O_ddr_ras_n
    .O_ddr_cas_n        (ddr_cas), //output O_ddr_cas_n
    .O_ddr_we_n         (ddr_we), //output O_ddr_we_n
    .O_ddr_clk          (ddr_ck), //output O_ddr_clk
    .O_ddr_clk_n        (ddr_ck_n), //output O_ddr_clk_n
    .O_ddr_cke          (ddr_cke), //output O_ddr_cke
    .O_ddr_odt          (ddr_odt), //output O_ddr_odt
    .O_ddr_reset_n      (ddr_reset_n), //output O_ddr_reset_n
    .O_ddr_dqm          (ddr_dm), //output [3:0] O_ddr_dqm
    .IO_ddr_dq          (ddr_dq), //inout [31:0] IO_ddr_dq
    .IO_ddr_dqs         (ddr_dqs), //inout [3:0] IO_ddr_dqs
    .IO_ddr_dqs_n       (ddr_dqs_n) //inout [3:0] IO_ddr_dqs_n
);
endmodule
