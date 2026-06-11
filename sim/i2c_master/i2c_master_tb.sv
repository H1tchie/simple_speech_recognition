module i2c_master_tb;

  // Parameters
  localparam CLK_FREQ = 50_000_000;  // 50 MHz clock
  localparam I2C_FREQ = 400_000;     // 400 kHz I2C clock

  // Signals
  reg clk;
  reg rst;
  reg ena;
  reg [6:0] addr;
  reg rw;
  reg [7:0] data_wr;
  wire busy;
  wire [7:0] data_rd;
  wire ack_error;
  tri sda;
  tri scl;

  // Clock generation
  initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50 MHz clock
  end

  // Instantiate the I2C Master module
  i2c_master #(
    .input_clk(CLK_FREQ),
    .bus_clk(I2C_FREQ)
  ) uut (
    .clk(clk),
    .rst(rst),
    .ena(ena),
    .addr(addr),
    .rw(rw),
    .data_wr(data_wr),
    .busy(busy),
    .data_rd(data_rd),
    .ack_error(ack_error),
    .sda(sda),
    .scl(scl)
  );

  // Test process
  initial begin
    // Initialize signals
    rst = 0;
    ena = 0;
    addr = 7'b0000000;
    rw = 0;
    data_wr = 8'b00000000;

    // Apply reset
    #100;
    rst = 1;
    #100
    rst = 0;

    // Test case 1: Write operation
    #100;
    addr = 7'b1010000;       // Example slave address
    rw = 0;                  // Write operation
    data_wr = 8'h55;         // Data to write
    ena = 1;                 // Enable transaction
    #20;
    ena = 0;                 // Disable transaction
    wait(busy == 0);         // Wait for transaction to complete
    if (ack_error) $display("Test Case 1 Failed: Ack error during write operation");
    else $display("Test Case 1 Passed");

    // Test case 2: Read operation
    #100;
    addr = 7'b1010000;       // Example slave address
    rw = 1;                  // Read operation
    ena = 1;                 // Enable transaction
    #20;
    ena = 0;                 // Disable transaction
    wait(busy == 0);         // Wait for transaction to complete
    if (ack_error) $display("Test Case 2 Failed: Ack error during read operation");
    else if (data_rd !== 8'hXX) $display("Test Case 2 Passed, Read Data: %h", data_rd);
    else $display("Test Case 2 Failed: Invalid data read");

    // Additional tests for edge cases, e.g., invalid address, handling NACK, etc.
    // Test case 3: Invalid address
    #100;
    addr = 7'b1111111;       // Invalid slave address
    rw = 0;                  // Write operation
    data_wr = 8'hAA;
    ena = 1;                 // Enable transaction
    #20;
    ena = 0;                 // Disable transaction
    wait(busy == 0);         // Wait for transaction to complete
    if (ack_error) $display("Test Case 3 Passed: Detected NACK for invalid address");
    else $display("Test Case 3 Failed: NACK not detected for invalid address");

    // Test case 4: Multiple byte transactions
    // Implement based on your specific protocol requirements...

    // End simulation
    #100;
    $finish;
  end

  // Monitor signals for debugging
  initial begin
    $monitor("Time: %0t | Busy: %b | Ack Error: %b | Data Read: %h | SDA: %b | SCL: %b", 
              $time, busy, ack_error, data_rd, sda, scl);
  end

endmodule
