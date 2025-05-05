module fifo (
    input clk,
    input rst,
    input en,
    input push_in,  //to write the data in fifo
    input pop_in,   //to read the data from fifo
    input [7:0] din,    // are the data bus
    input [3:0] thres,   //Threshold regarding 4 bytes
    output  [7:0] dout, // data bus
    output  empty,       
    output  full,
    output  underrun,    //that indicates fifo are empty but a pop request is still being performed
    output  overrun,     //indicates that the fifo is full, but we are still trying to push data into it
    output  thres_tri  // Is set when the write address reaches the threshold
);
    

    reg [7:0] mem [16];
    reg [3:0] waddr = 0;
    reg [3:0] raddr = 0;
    
    wire push,pop;

    //Empty Flag
    reg empty_flag;
    
    always @(posedge clk) begin
        if(rst) begin
            empty_flag <= 0;
        end
        else begin
            case({push,pop})
                2'b01: empty_flag <= ((waddr == 0) | ~en);    // Fifo is not enabled
                2'b10: empty_flag <= 1'b0;

                default : ;
            endcase    
        end
    end


    //Full Flage
    reg full_flag;

    always @(posedge clk) begin
        if(rst) begin
            full_flag <= 0;
        end
        else begin
            case({push,pop}) 
                2'b10: full_flag <=  (&(waddr) | ~en );
                2'b01: full_flag <= 1'b0;

                default: ;
            endcase       
        end
        
    end



    // Assign push & pop
    assign push = push_in & ~full_flag;
    assign pop = pop_in & ~empty_flag;

    assign dout = mem[0];

    //For writing address pointer
    always @(posedge clk) begin
        if(rst) begin
            waddr <= 4'h0;

        end 
        else begin
            case({push,pop})
            2'b10: begin
                if(waddr != 4'hf && full_flag == 1'b0)
                    waddr <= waddr + 1;
                else 
                    waddr <= waddr;
            end

            2'b01: begin
                if(waddr != 0 && empty_flag == 1'b0) 
                    waddr <= waddr - 1;
                else
                    waddr <= waddr;
            end

            default: ;
            endcase
        end      
    end

    //Memory update
    integer  i = 0;
    always @(posedge clk) begin
        case ({push,pop})
            2'b00 : ; // No push or pop, do nothing
            
            2'b01 :  begin
                // POP only: shift all data forward by 1
                for ( i = 0; i < 14; i++) begin
                        mem[i] <= mem[i+1]; 
                end
                mem[15] <= 8'h00;
            end

            2'b10 : begin
                // PUSH only: write new data at waddr
                mem[waddr] <= din;
            end

            2'b11 : begin
                // PUSH + POP: shift data (as if pop first), then write at waddr-1
                for ( i = 0; i < 14; i++) begin
                        mem[i] <= mem[i+1]; 
                end
                mem[15] <= 8'h00;
                mem[waddr - 1] <= din;
            end
    
        endcase
        
    end

    //Underrun Flag
    reg underrun_t;

    always @(posedge clk) begin
        if(rst) 
            underrun_t <= 1'b0;
        else if (pop_in == 1'b1 && empty_flag == 1'b1)
            underrun_t <= 1'b1;
        else 
            underrun_t <= 1'b0;            
    end


    //Overrun Flag
    reg overrun_t = 0;

    always @(posedge clk) begin
        if(rst) 
        overrun_t <= 1'b0;
        else if (push_in == 1'b1 && full_flag == 1'b1) 
            overrun_t <= 1'b1;
        else 
            overrun_t <= 1'b0;
    end


    //Threshold Flag
    reg thres_t;

    always @(posedge clk) begin
        if(rst) begin
            thres_t <= 1'b0;            
        end
        else if (push ^ pop)  begin
            thres_t <= (waddr >= thres) ? 1'b1 : 1'b0;
        end
        
    end


    //Assigning
    assign empty = empty_flag;
    assign full = full_flag;
    assign overrun = overrun_t;
    assign underrun = underrun_t;
    assign thres_tri = thres_t;


    
endmodule