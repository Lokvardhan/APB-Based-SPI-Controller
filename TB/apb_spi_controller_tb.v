//------------------------------------------------------------------------------
// Module Name : apb_spi_controller_tb
//
// Description :
// Testbench for the APB-based SPI controller.
//
// The testbench:
//   - Generates the APB clock.
//   - Applies reset.
//   - Configures SPI registers through APB writes.
//   - Reads SPI registers through APB.
//   - Provides serial MISO stimulus.
//   - Verifies PSLVERR for invalid APB accesses.
//   - Monitors APB read/write activity.
//------------------------------------------------------------------------------


module apb_spi_controller_tb;

    //==========================================================================
    // Testbench Signals
    //==========================================================================

    reg        pclk;
    reg        preset_n;
    reg        pwrite;
    reg        psel;
    reg        penable;
    reg  [2:0] paddr;
    reg  [7:0] pwdata;
    reg        miso;

    wire       pready;
    wire       spi_interupt_request;
    wire       pslverr;
    wire       sclk;
    wire       ss;
    wire       mosi;
    wire [7:0] prdata;

    integer i;
    integer j;
    integer k;
    integer l;


    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    apb_spi_controller dut (
        .pclk                  (pclk),
        .preset_n              (preset_n),
        .pwrite                (pwrite),
        .psel                  (psel),
        .penable               (penable),
        .paddr                 (paddr),
        .pwdata                (pwdata),
        .miso                  (miso),
        .pready                (pready),
        .pslverr               (pslverr),
        .sclk                  (sclk),
        .ss                    (ss),
        .mosi                  (mosi),
        .prdata               (prdata),
        .spi_interupt_request (spi_interupt_request)
    );


    //==========================================================================
    // PCLK Generation
    //==========================================================================

    initial begin
        pclk = 1'b0;
        forever #5 pclk = ~pclk;
    end


    //==========================================================================
    // Testbench Initialization
    //==========================================================================

    task initialize;
    begin
        preset_n = 1'b0;
        pwrite   = 1'b0;
        psel     = 1'b0;
        penable  = 1'b0;
        paddr    = 3'b000;
        pwdata   = 8'b0;
        miso     = 1'b0;
    end
    endtask


    //==========================================================================
    // Reset
    //==========================================================================

    task reset;
    begin
        @(negedge pclk);
        preset_n = 1'b0;

        @(negedge pclk);
        preset_n = 1'b1;
    end
    endtask


    //==========================================================================
    // APB Write Transaction
    //
    // APB sequence:
    // IDLE -> SETUP -> ENABLE -> IDLE
    //==========================================================================

    task wstimulus(input [2:0] pa, input [7:0] pwda);
    begin
        @(negedge pclk);
        pwdata = pwda;
        paddr  = pa;
        psel   = 1'b1;
        pwrite = 1'b1;

        @(negedge pclk);
        penable = 1'b1;

        @(negedge pclk);
        psel    = 1'b0;
        penable = 1'b0;
    end
    endtask


    //==========================================================================
    // APB Read Transaction
    //==========================================================================

    task rstimulus(input [2:0] pa);
    begin
        @(negedge pclk);
        paddr  = pa;
        pwrite = 1'b0;
        psel   = 1'b1;

        @(negedge pclk);
        penable = 1'b1;

        @(negedge pclk);
        psel    = 1'b0;
        penable = 1'b0;
    end
    endtask


    //==========================================================================
    // PSLVERR Verification
    //
    // This task uses the same APB timing as the working write transaction.
    // PSLVERR is checked while the APB transfer is still in the ENABLE phase.
    //==========================================================================

    task pslverr_write_check(
        input [2:0] pa,
        input [7:0] pwda,
        input       expected_error
    );
    begin
        // APB SETUP phase
        @(negedge pclk);
        pwdata = pwda;
        paddr  = pa;
        psel   = 1'b1;
        pwrite = 1'b1;

        // APB ENABLE phase
        @(negedge pclk);
        penable = 1'b1;

        // Check PSLVERR while transfer is active
        @(negedge pclk);

        if (pslverr !== expected_error) begin
            $display("ERROR: PSLVERR check failed | ADDR=%b | EXPECTED=%b | ACTUAL=%b",
                     pa, expected_error, pslverr);
        end
        else begin
            $display("PASS : PSLVERR check | ADDR=%b | PSLVERR=%b",
                     pa, pslverr);
        end

        // End APB transaction
        psel    = 1'b0;
        penable = 1'b0;
    end
    endtask


    //==========================================================================
    // MISO Stimulus Tasks
    //
    // The first MISO bit is assigned before the first SCLK edge so that the
    // SPI receiver has valid data when the first sampling edge occurs.
    //==========================================================================

    // MSB-first data.
    // MISO is updated on the falling edge of SCLK.
    task miso_input_msb_pos(input [7:0] mi);
    begin
        miso = mi[7];

        for (i = 6; i >= 0; i = i - 1) begin
            @(negedge sclk);
            miso = mi[i];
        end
    end
    endtask


    // LSB-first data.
    // MISO is updated on the rising edge of SCLK.
    task miso_input_lsb_pos(input [7:0] mi);
    begin
        miso = mi[0];

        for (j = 1; j < 8; j = j + 1) begin
            @(posedge sclk);
            miso = mi[j];
        end
    end
    endtask


    // MSB-first data.
    // MISO is updated on the falling edge of SCLK.
    task miso_input_msb_neg(input [7:0] mi);
    begin
        miso = mi[7];

        for (k = 6; k >= 0; k = k - 1) begin
            @(negedge sclk);
            miso = mi[k];
        end
    end
    endtask


    // LSB-first data.
    // MISO is updated on the falling edge of SCLK.
    task miso_input_lsb_neg(input [7:0] mi);
    begin
        miso = mi[0];

        for (l = 1; l < 8; l = l + 1) begin
            @(negedge sclk);
            miso = mi[l];
        end
    end
    endtask


    //==========================================================================
    // Main Test Sequence
    //==========================================================================

    initial begin

        // Initialize testbench signals
        initialize;

        // Apply reset
        reset;


        //========================================================================
        // SPI Register Configuration
        //
        // Address 010 : SPI_BR
        // Address 000 : SPI_CR1
        // Address 001 : SPI_CR2
        // Address 101 : SPI_DR
        //========================================================================

        wstimulus(3'b010, 8'b1010_0001);    // SPI_BR
        wstimulus(3'b000, 8'b1111_0011);    // SPI_CR1
        wstimulus(3'b001, 8'b0011_0000);    // SPI_CR2
        wstimulus(3'b101, 8'b1001_1111);    // SPI_DR


        //========================================================================
        // Read SPI Status Register
        //========================================================================

        rstimulus(3'b011);                  // SPI_SR


        //========================================================================
        // SPI Transfer
        //========================================================================

        wait (!ss);

        miso_input_msb_pos(8'b0010_1010);

        wait (ss);


        //========================================================================
        // Read Received SPI Data
        //========================================================================

        rstimulus(3'b101);                  // SPI_DR


        //========================================================================
        // PSLVERR Verification
        //
        // Address 100 : Reserved address
        // Address 110 : Reserved address
        // Address 111 : Reserved address
        // Address 011 : SPI_SR is read-only
        //========================================================================

        pslverr_write_check(3'b100, 8'hAA, 1'b1);
        pslverr_write_check(3'b110, 8'hAA, 1'b1);
        pslverr_write_check(3'b111, 8'hAA, 1'b1);
        pslverr_write_check(3'b011, 8'hAA, 1'b1);


        //========================================================================
        // End Simulation
        //========================================================================

        $display("==============================================");
        $display("       APB SPI CONTROLLER TEST COMPLETE      ");
        $display("==============================================");

        #20;
        $finish;

    end


    //==========================================================================
    // APB Activity Monitor
    //==========================================================================

   initial 
	begin
    $monitor("Time=%0t | PADDR=%03b | PWRITE=%b | PSEL=%b | PENABLE=%b | PWDATA=%08b | PRDATA=%08b | PREADY=%b | PSLVERR=%b | SS=%b | SCLK=%b | MOSI=%b | MISO=%b",
             $time,
             paddr,
             pwrite,
             psel,
             penable,
             pwdata,
             prdata,
             pready,
             pslverr,
             ss,
             sclk,
             mosi,
             miso);
	end

endmodule
