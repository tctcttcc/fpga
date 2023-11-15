module ov5640_top(
    input           clk_50m         ,
    input           sys_rst         ,
    inout           cmos_scl        ,
    inout           cmos_sda        ,
    input           cmos_pclk       ,
    input           cmos_href       ,
    input           cmos_vsync      ,
    input   [7:0]   cmos_db         , 
    input           sys_init_done   ,
    output          ov5640_wr_en    ,
    output  [15:0]  cmos_16bit_data ,
    output          wr_vsync        ,
    output          cfg_done        
);

wire    [31:0]  lut_data;
wire    [9:0]   lut_index;
wire            cfg_end;
//wire            cfg_done;

//I2C master controller
i2c_config i2c_config_m0(
	.rst                        (sys_rst              ),
	.clk                        (clk_50m                ),
	.clk_div_cnt                (16'd500                  ),
	.i2c_addr_2byte             (1'b1                     ),
	.lut_index                  (lut_index                ),
	.lut_dev_addr               (lut_data[31:24]          ),
	.lut_reg_addr               (lut_data[23:8]           ),
	.lut_reg_data               (lut_data[7:0]            ),
	.error                      (                         ),
	.done                       (cfg_end                  ),
	.i2c_scl                    (cmos_scl                 ),
	.i2c_sda                    (cmos_sda                 )
);
//configure look-up table
lut_ov5640_rgb565_480_272 lut_ov5640_rgb565_480_272_m0(
    .clk50m                     (clk50m                 ),
    .sys_rst                    (sys_rst                ),
    .cfg_end                    (cfg_end                  ),
	.lut_index                  (lut_index                ),
    .cfg_done                   (cfg_done                 ),
	.lut_data                   (lut_data                 )
);

ov5640_data ov5640_data_inst(
    .sys_rst_n          (!sys_rst & sys_init_done),  //复位信号
    .ov5640_pclk        (cmos_pclk    ),   //摄像头像素时钟
    .ov5640_href        (cmos_href    ),   //摄像头行同步信号
    .ov5640_vsync       (cmos_vsync   ),   //摄像头场同步信号
    .ov5640_data        (cmos_db),   //摄像头图像数据

    .ov5640_wr_en       (ov5640_wr_en   ),   //图像数据有效使能信号
    .ov5640_data_out    (cmos_16bit_data),   //图像数据
    .wr_vsync           (wr_vsync       )
);

//CMOS sensor 8bit data is converted to 16bit data
/*
cmos_8_16bit cmos_8_16bit_m0(
    .rst_n            (sys_rst_n&locked),  //复位信号    
    //摄像头接口                           
    .cam_pclk         (cmos_pclk),  //cmos 数据像素时钟
    .cam_vsync        (cmos_vsync),  //cmos 场同步信号
    .cam_href         (cmos_href),  //cmos 行同步信号
    .cam_data         (cmos_db),                      
    //用户接口                              
    .cmos_frame_vsync (cmos_frame_vsync),  //帧有效信号    
    .cmos_frame_href  (),  //行有效信号
    .cmos_frame_valid (ov5640_wr_en),  //数据有效使能信号
    .cmos_frame_data  (cmos_16bit_data)  //有效数据        
    );
*/

endmodule


