module fifo_tb;
    reg rst, clk, en, push_in, pop_in;
    reg [7:0] din;
    wire [7:0] dout;
    wire empty, full, overrun, underrun;
    reg [3:0] thres;
    wire thres_tri;

    // Initialize signals
    initial begin
        rst = 0;
        clk = 0;
        en = 0;
        din = 0;
    end

    // Instantiate the FIFO module
    fifo dut_fifo (
        .clk(clk),
        .rst(rst),
        .en(en),
        .push_in(push_in),
        .pop_in(pop_in),
        .din(din),
        .thres(thres),
        .dout(dout),
        .empty(empty),
        .full(full),
        .underrun(underrun),
        .overrun(overrun),
        .thres_tri(thres_tri)
    );

    // Clock Generation (period = 10 time units)
    always #5 clk = ~clk;

    // Testbench logic
    initial begin
        // Reset pulse
        rst = 1'b1;
        repeat(5) @(posedge clk);
        rst = 1'b0;

        // Push data into FIFO (write operation)
        integer i;
        for(i = 0; i < 20; i = i + 1) begin
            push_in = 1'b1;     // Assert push signal
            din = $urandom();   // Random data input
            pop_in = 1'b0;      // Deassert pop signal
            en = 1'b1;          // Enable FIFO
            thres = 4'ha;       // Set threshold value
            @(posedge clk);     // Wait for clock edge
        end

        // Read data from FIFO (read operation)
        for(i = 0; i < 20; i] = i + 1) begin
            push_in = 1'b0;     // Deassert push signal
            din = 8'b0;         // Clear data input (no write)
            pop_in = 1'b1;      // Assert pop signal
            en = 1'b1;          // Enable FIFO
            thres = 4'ha;       // Set threshold value
            @(posedge clk);     // Wait for clock edge
        end
    end

    // VCD waveform generation
    initial begin
        $dumpfile("fifo.vcd");    // VCD file name
        $dumpvars(0, fifo_tb);    // Dump all variables in the top module
    end

endmodule
