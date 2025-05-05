    module rx (
        input clk, rst, baud_pulse,rx,sticky_parity, eps,
        input pen,
        input [1:0] wls,
        output reg push,
        output reg pe, fe, bi, // parity error , frame error, break indicator
        output reg [7:0] dout

    );

        typedef enum logic [2:0] {IDLE = 0, START = 1, READ = 2, PARITY = 3, STOP = 4 } state_type;
        state_type state = IDLE;


        //Detect Falling Edge
        reg rx_reg = 1'b1;
        wire fall_edge;


        always @(posedge clk) begin
            rx_reg <= rx;
            
        end

        assign fall_edge = rx_reg;


        //registers
        reg [2:0] bitcnt;
        reg [3:0] count = 0;
        reg [7:0] dout = 0;
        reg pe_reg; // Parity Error 

        always @(posedge clk or posedge rst) begin
            if(rst) begin
                state <= IDLE;
                push <= 1'b0;
                pe <= 1'b0; // Parity Error
                fe <= 1'b0; // Frame Error
                bi <= 1'b0; // Break Indicator
                bitcnt <= 8'h00;
            end
            else begin
                push <= 1'b0;
                
                if(baud_pulse) begin
                    case (state) 

                    /// Idle State
                    IDLE: begin
                        if(!fall_edge) begin
                            state <= START;
                            count <= 5'd15;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end
                    ///Detect Start

                    START: begin
                        count <= count - 1;

                        if(count == 5'd7) begin
                            if(rx == 1'b1) begin
                                state <= IDLE;
                                count <= 5'd15;
                            end
                            else begin
                                state <= START;
                            end
                        end
                        else if (count == 0) begin
                            state <= READ;
                            count <= 5'd15;
                            bitcnt <= {1'b1, wls};
                        end
                    end

                    ///Read Byte From RX pin
                    READ: begin
                        count <= count - 1;

                        if(count == 5'd7) begin
                            
                            case(wls) 
                            2'b00: dout <= {3'b000, rx, dout[4:1]};
                            2'b01: dout <= {2'b00, rx, dout[5:1]};
                            2'b10: dout <= {1'b0, rx, dout[6:1]};
                            2'b11: dout <= {    rx, dout[7:1]};

                            endcase

                            state <= READ;

                        end
                        else if (count == 0 ) begin
                            if(bitcnt == 0) begin
                                
                            case({sticky_parity, eps})
                                2'b00: pe_reg <= ~^{rx, dout}; // Odd parity
                                2'b01: pe_reg <=  ^{rx, dout}; // Even parity
                                2'b10: pe_reg <= ~rx;          // Sticky parity = 1
                                2'b11: pe_reg <=  rx;          // Sticky parity = 0
                            endcase

                                if(pen == 1'b1) begin
                                    state  <= PARITY;
                                    count <= 5'd15;
                                end
                                else begin
                                    state <= STOP;
                                    count <= 5'd15;
                                end

                            end 
                            //bitcnt reaches 0 
                            else begin
                                bitcnt <= bitcnt - 1;
                                state <= READ;
                                count <= 5'd15;
                            end
                            //Send rest of Bits
                        end
                    end

                    //Detect Parity Erro
                    PARITY:  begin
                        count <= count - 1;
                            if (count == 5'd7) begin
                                pe <= pe_reg;
                                state <= PARITY;
                            end 

                            else if (count == 0) begin
                                state <= STOP;
                                count <= 5'd15;
                            end
                    end

                    //Detect frame error
                    STOP: begin
                        count <= count - 1;
                            if(count == 5'd7) begin
                                fe <= ~rx;
                                push <= 1'b1;
                                state <= STOP;
                            end 
                            else if(count == 0) begin
                                state <= IDLE;
                                count <= 5'd15;
                            end
                    end

                    default: ;

                    endcase
                end

            end
        end

        
    endmodule