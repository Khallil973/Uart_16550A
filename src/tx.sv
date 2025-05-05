module tx(
    input clk, rst, baud_pulse, pen, thres, stb, sticky_parity, eps, set_break,
    input [7:0] din,
    input [1:0] wls,
    output reg pop, sreg_empty, tx
);

    reg [7:0] shift_reg;
    reg tx_data;
    reg d_parity;
    reg [2:0] bitcnt = 0;
    reg [4:0] count = 5'd15;
    reg parity_out;

    typedef enum logic[1:0] {IDLE = 0, START = 1, SEND = 2, PARITY = 3} state_type;
    state_type state = IDLE;


    always@(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 5'd15;
            bitcnt <= 0;
            shift_reg <= 8'b00000000;
            pop <= 1'b0;
            sreg_empty <= 1'b0;
            tx_data <= 1'b1; // Start bit high 1
            state <= IDLE;

        end

        else if (baud_pulse) begin
            case (state) 
                IDLE: begin
                    if (thres == 1'b0) begin //csr.lsr.thres
                        if(count != 0) begin
                            count <= count - 1;
                            state <= IDLE;
                        end
                        else begin
                            count <= 5'd15;
                            state <= START;
                            bitcnt <= {1'b1, wls};
                            pop <= 1'b1; //read tx to fifo
                            shift_reg <= din; //to store the data of fifo
                            sreg_empty <= 1'b0; 
                            tx_data <= 1'b1; //START bit high
                        end 
                    end
                end 

                START: begin
                    //Calculate parity to check the odd & even bit
                    case (wls) 
                        2'b00: d_parity <= ^din[4:0];
                        2'b01: d_parity <= ^din[5:0];
                        2'b10: d_parity <= ^din[6:0];
                        2'b11: d_parity <= ^din[7:0];
                    endcase



                    if (count != 0) begin
                        count <= count - 1;
                        state <= START;
                    end 
                    else begin
                        count <= 5'd15;
                        state <= SEND;
                        tx_data <= shift_reg[0]'
                        shift_reg <= shift_reg >> 1;
                        pop <= 1'b0;

                    end 
                end

                //Send 
                SEND: begin
                    case({sticky_parity,eps}) 
                        2'b00: parity_out <= ~d_parity; // odd
                        2'b01: parity_out <= d_parity; // even
                        2'b10: parity_out <= 1'b1;
                        2'b11: parity_out <= 1'b0;
                    endcase 


                    if(bitcnt != 0) begin
                        if(count != 0) begin
                            count <= count - 1;
                            state <= SEND;
                        end
                        else begin
                            count <= 5'd15;
                            bitcnt <= bitcnt - 1;
                            tx_data <= shift_reg[0];
                            shift_reg <= shift_reg >> 1;
                            state <= SEND;
                        end
                    end
                    else begin
                        if(count != 0) begin
                            count <= count - 1;
                            state <= SEND;
                        end
                        else begin
                            count <= 5'd15;
                            sreg_empty <= 1'b1;

                            if(pen == 1'b1) begin
                                state <= PARITY;
                                count <= 5'd15;
                                tx_data <= parity_out;
                            end
                            else begin
                                tx_data <= 1'b1;
                                count <= (stb == 1'b0) ? 5'd15 : (wls == 2'b00) ? 5'd23 : 5'd31;
                                state <= IDLE;
                            end
                        end
                    end   //else for bitcnt loop
                end

                PARITY: begin
                    if(count != 0) begin
                        count <= count - 1;
                        state <= PARITY;
                    end
                    else begin
                        tx_data <= 1'b1;
                        count <= (stb == 1'b0) ? 5'd15 : (wls == 2'b00) ? 5'd17 : 5'd31;
                        state <= IDLE;
                    end
                end

                default: ;
            endcase
        end
    end



    always@ (posedge clk, posedge rst) begin
        if (rst) begin
            tx <= 1'b1; //for start bit
        end
        else begin
            tx <= tx_data & ~set_break;
        end
    end

endmodule