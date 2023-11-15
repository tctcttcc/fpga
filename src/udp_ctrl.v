module udp_ctrl(
    input                clk        , //输入时钟   
    input                rst_n      , //复位信号，低电平有效
    
    input                touch_key  , //触摸按键,用于触发开发板发出ARP请求
    output  reg          tx_start_en  , //UDP发送使能信号
    inout                led        
    );


//reg define
reg         touch_key_d0;
reg         touch_key_d1;

//wire define
wire        neg_touch_key;  //touch_key信号下降沿升沿

reg         led_t;

assign      led = led_t;

//*****************************************************
//**                    main code
//*****************************************************

assign neg_touch_key = touch_key_d1 & (~touch_key_d0);

//对arp_tx_en信号延时打拍两次,用于采touch_key的下降沿
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        touch_key_d0 <= 1'b1;
        touch_key_d1 <= 1'b1;
    end
    else begin
        touch_key_d0 <= touch_key;
        touch_key_d1 <= touch_key_d0;
    end
end

//为arp_tx_en和arp_tx_type赋值
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        tx_start_en <= 1'b0;
        led_t <= 1'b1;
    end
    else begin
        led_t = led;
        if(neg_touch_key == 1'b1) begin  //检测到输入触摸按键下降沿
            tx_start_en <= ~tx_start_en;           
            led_t <= ~led_t;
        end
       
    end
end

endmodule
