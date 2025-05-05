
        //LCR
    typedef struct packed{
        logic dlab;
        logic set_break;
        logic sticky_parity;
        logic eps;
        logic pen;
        logic stb;
        logic [1:0] wls;
    }lcr_t;

    //Division Latch DL
    typedef struct packed{
        logic [7:0] dmsb;   //Divisor Latch MSB
        logic [7:0] dlsb;   //Divisonr Latch LSB

    }div_t;

     ////////////FCR
    typedef struct packed{
    logic  [1:0] rx_trigger;        //Receive trigger
    logic [1:0] reserved;          //reserved
    logic       dma_mode;          //DMA mode select
    logic       tx_rst;            //Transmit FIFO Reset
    logic       rx_rst;            //Receive FIFO Reset
    logic       ena;               //FIFO enabled
  } fcr_t; //Fifo Control register

     ////////////// LSR
   typedef struct packed {
    logic       rx_fifo_error;
    logic       temt;              //Transmitter Emtpy
    logic       thre;              //Transmitter Holding Register Empty
    logic       bi;                //Break Interrupt
    logic       fe;                //Framing Error
    logic       pe;                //Parity Error
    logic       oe;                //Overrun Error
    logic       dr;                //Data Ready
  } lsr_t; //Line Status Register

    ////struct to hold all registers
    typedef struct packed{
        fcr_t fcr;
        lcr_t lcr;
        lsr_t lsr;
        logic [7:0] scr;
    }csr_t;


module uart_reg (
    input clk,rst,
    input wr_i, rd_i,
    input rx_fifo_empty_i,
    input rx_oe, rx_pe, rx_fe, rx_bi,
    input [2:0] addr_i,
    input [7:0] din_i,
    input [7:0] rx_fifo_in,

    output tx_push_o, ///add new data to TX FIFO
    output rx_pop_o, ///read data from RX FIFO

    output reg [7:0] dout_o,
    output tx_rst, rx_rst,

    output baud_out, //baud pulse for both tx and rx
    output [3:0] rx_fifo_threshold,
    output csr_t csr_o


);


/*
    ////struct to hold all registers
    typedef struct packed{
        fcr_t fcr;
        lcr_t lcr;
        lsr_t lsr;
        logic [7:0] scr;
    }csr_t;
*/
    csr_t csr;


 
 
//-----------------------------------------------------------------------

/*
    //LCR
    typedef struct packed{
        logic dlab;
        logic set_break;
        logic sticky_parity;
        logic eps;
        logic pen;
        logic stb;
        logic [1:0] wls;
    }lcr_t;
*/
    lcr_t lcr;


    wire tx_fifo_wr;

    assign tx_fifo_wr = wr_i & (addr_i == 3'b000) & (csr.lcr.dlab == 1'b0);
    assign tx_push_o = tx_fifo_wr;
    
//
    wire rx_fifo_rd;

    assign rx_fifo_rd = rd_i & (addr_i == 3'b000) & (csr.lcr.dlab == 1'b0);
    assign rx_pop_o = rx_fifo_rd;



    reg [7:0] rx_data;//Temperaroy variable for temperoray hold the data read from Fifo

    always @(posedge clk) begin
        if(rx_pop_o) begin
            rx_data <= rx_fifo_in;
        end
    end


//----------------------------------------------------------------------------
 /*
    //Division Latch DL
    typedef struct packed{
        logic [7:0] dmsb;   //Divisor Latch MSB
        logic [7:0] dlsb;   //Divisonr Latch LSB

    }div_t;
*/
    div_t dl;


    //Update dlsb if wr = 1, dlab = 1, addr = 0
    always @(posedge clk) begin
        if(wr_i && addr_i == 3'b000 && csr.lcr.dlab == 1) begin
            dl.dlsb <= din_i;
        end
    end


    //Update dmsb if wr = 1, dlab = 1, addr = 1
    always @(posedge clk) begin
        if(wr_i && addr_i == 3'b001 && csr.lcr.dlab == 1) begin
            dl.dmsb <= din_i;
        end
    end



    reg update_baud;
    reg [15:0] baud_cnt = 0;
    reg baud_pulse;
    wire baud_latch_write = wr_i & (csr.lcr.dlab == 1'b1) & ((addr_i == 3'b000) | (addr_i == 3'b001));

    ///Sense update in baud values
    always @(posedge clk) begin
        if(rst) begin
            update_baud <= 1'b0;
        end
        else if(baud_latch_write) begin
            update_baud <= 1'b1;
        end
        else begin
            update_baud <= 1'b0;
        end
    end


    //Baud Counter
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            baud_cnt <= 16'h0;
            baud_pulse <= 0;
        end    
        else if (update_baud || baud_cnt == 16'h0000) begin
            baud_cnt <= {dl.dmsb, dl.dlsb};
        end    
        else begin
            baud_cnt <= baud_cnt - 1;    
        end    
    end


    //Generate baud pulse when baud count becomes zero
    always @(posedge clk) begin
       // baud_pulse <=  |(dl & (~(|baud_cnt)));    
        baud_pulse <= (baud_cnt == 0) && (|dl.dmsb | |dl.dlsb);
    end


    assign baud_out = baud_pulse;  //baud pulse for both tx ans rx

//--------------------------------------------------------------------
/*  
     ////////////FCR
    typedef struct packed{
    logic  [1:0] rx_trigger;        //Receive trigger
    logic [1:0] reserved;          //reserved
    logic       dma_mode;          //DMA mode select
    logic       tx_rst;            //Transmit FIFO Reset
    logic       rx_rst;            //Receive FIFO Reset
    logic       ena;               //FIFO enabled
  } fcr_t; //Fifo Control register
*/
    fcr_t fcr;
     
    
    ////fifo write operation-> read data from user and update bits of fcr
 
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            csr.fcr <= 8'h00;
        end
        else if (wr_i == 1'b1 && addr_i == 3'h2) begin //ADDRESS == 2H 
            csr.fcr.rx_trigger <= din_i[7:6];
            csr.fcr.dma_mode <= din_i[3];
            csr.fcr.tx_rst <= din_i[2];
            csr.fcr.rx_rst <= din_i[1];
            csr.fcr.ena <= din_i[0]; 
        end
        else begin
            csr.fcr.tx_rst <= 1'b0;
            csr.fcr.rx_rst <= 1'b0;

        end
    end

    ////reset tx and rx fifo --> go to tx and rx fifo
    assign tx_rst = csr.fcr.tx_rst;
    assign rx_rst = csr.fcr.rx_rst;

//---------------------------------------------------------------------------------

     
////////////////// Line Control Register --> defines format of transmitted data
    /// 0000 1100
    reg [7:0] lcr_temp;

    //Write new data to LCR
    always @(posedge clk) begin
        if (rst) begin
            csr.lcr <= 8'h00;
        end
        else if (wr_i == 1'b1 && addr_i == 3'h3) begin
            csr.lcr <= din_i;
        end
    end


    //Read LCR
    wire read_lcr;

    assign read_lcr = ((rd_i == 1) && (addr_i == 3'h3));

    always @(posedge clk) begin
        if(read_lcr) begin
            lcr_temp <= csr.lcr;
        end
    end

//---------------------------------------------------------------
/*
     ////////////// LSR
   typedef struct packed {
    logic       rx_fifo_error;
    logic       temt;              //Transmitter Emtpy
    logic       thre;              //Transmitter Holding Register Empty
    logic       bi;                //Break Interrupt
    logic       fe;                //Framing Error
    logic       pe;                //Parity Error
    logic       oe;                //Overrun Error
    logic       dr;                //Data Ready
  } lsr_t; //Line Status Register
*/  
    lsr_t lsr;
    //update content of LSR register
    always @(posedge clk) begin
        if(rst) begin
            csr.lsr <= 8'h60; //// both fifo and shift register are empty thre = 1 , tempt = 1  // 0110 0000
        end
        else begin
            csr.lsr.dr <= ~rx_fifo_empty_i;
            csr.lsr.oe <= rx_oe;
            csr.lsr.pe <= rx_pe;
            csr.lsr.fe <= rx_fe;
            csr.lsr.bi <= rx_bi;
        end
    end



    //Read register contents

    reg [7:0] lsr_temp;
    wire read_lsr;

    //ADDR = 5H
    assign read_lsr = ((rd_i == 1) && (addr_i == 3'h5));

    always @(posedge clk) begin
        if (read_lsr) begin
            lsr_temp <= csr.lsr;
        end
    end

//-----------------------------------------------------

    //Scrtchpad register

    //write new data to scr
    always @(posedge clk) begin
        if(rst) begin
            csr.scr <= 8'h00;
        end
        else if(wr_i == 1'b1 && addr_i == 3'h7) begin
            csr.scr <= din_i;
        end
    end

    //From read through scr
    reg [7:0] scr_temp;
    wire read_scr;

    assign read_scr = (rd_i == 1) && (addr_i == 3'h7); 

    always @(posedge clk) begin
        if (read_scr) begin
            scr_temp <= csr.scr;
        end
    end

//-------------------------------------------------------------------------

    always @(posedge clk) begin
        case(addr_i)
            0: dout_o <= csr.lcr.dlab ? dl.dlsb : rx_data;  
            1: dout_o <= csr.lcr.dlab ? dl.dmsb : 8'h00;  //csr.ier
            2: dout_o <= 8'h00; // iir
            3: dout_o <= lcr_temp; // lcr
            4: dout_o <= 8'h00; // mcr
            5: dout_o <= lsr_temp; //lsr
            6: dout_o <= 8'h00; //msr
            7: dout_o <= scr_temp; //scr
            default : ;
        endcase
     end

    assign csr_o = csr;

endmodule