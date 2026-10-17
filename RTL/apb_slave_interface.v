//------------------------------------------------------------------------------
// Module Name : apb_slave_interface
//
// Description :
// APB slave interface for the SPI controller.
//
// This module:
//   - Handles APB setup and access phases.
//   - Implements the SPI control, configuration, status, and data registers.
//   - Provides SPI configuration signals to the SPI functional blocks.
//   - Receives SPI data and transfer status from the SPI functional blocks.
//   - Generates APB read data, PREADY, PSLVERR, and SPI interrupt request.
//
// Register Map:
//   0x0 : SPI Control Register 1 (SPI_CR1)
//   0x1 : SPI Control Register 2 (SPI_CR2)
//   0x2 : SPI Baud Rate Register (SPI_BR)
//   0x3 : SPI Status Register (SPI_SR)
//   0x4 : Reserved
//   0x5 : SPI Data Register (SPI_DR)
//   0x6 : Reserved
//   0x7 : Reserved
//------------------------------------------------------------------------------

module apb_slave_interface(
    input        pclk,
    input        preset_n,
    input        pwrite_i,
    input        psel_i,
    input        penable_i,
    input        ss_i,
    input        receive_data_i,
    input        tip_i,
    input  [2:0] paddr_i,
    input  [7:0] pwdata_i,
    input  [7:0] miso_data_i,

    output       mstr_o,
    output       cpol_o,
    output       cpha_o,
    output       lsbfe_o,
    output       spiswai_o,
    output       pready_o,
    output       pslverr_o,

    output reg   send_data_o,
    output reg   spi_interrupt_request_o,
    output reg [7:0] prdata_o,
    output reg [7:0] mosi_data_o,

    output [2:0] sppr_o,
    output [2:0] spr_o,
    output reg [1:0] spi_mode_o
);


    //============================================================
    // APB and SPI State Definitions
    //============================================================

    parameter idle  = 2'b00,
              setup  = 2'b01,
              enable = 2'b10;

    parameter spi_run  = 2'b00,
              spi_wait = 2'b01,
              spi_stop = 2'b10;


    //============================================================
    // Register Write Masks
    //============================================================

    // Defines the writable bits of SPI_CR2 and SPI_BR.
    parameter cr2_mask = 8'b0001_1011,
              br_mask  = 8'b0111_0111;


    //============================================================
    // Internal Registers and Signals
    //============================================================

    reg [1:0] next_mode;
    reg [1:0] state;
    reg [1:0] next_state;

    // SPI registers
    reg [7:0] spi_cr_1;
    reg [7:0] spi_cr_2;
    reg [7:0] spi_br;
    reg [7:0] spi_sr;
    reg [7:0] spi_dr;

    // SPI status and control signals
    wire sptef;
    wire spif;
    wire spe;
    wire modfen;
    wire modf;
    wire ssoe;
    wire spie;
    wire sptie;

    // APB access control
    wire wr_enb;
    wire rd_enb;

    // Address validation and APB error detection
    wire valid_addr;
    wire write_readonly_reg;


    //============================================================
    // SPI Control Register Bit Mapping
    //============================================================

    assign spie       = spi_cr_1[7];
    assign spe        = spi_cr_1[6];
    assign sptie      = spi_cr_1[5];
    assign mstr_o     = spi_cr_1[4];
    assign cpol_o     = spi_cr_1[3];
    assign cpha_o     = spi_cr_1[2];
    assign ssoe       = spi_cr_1[1];
    assign lsbfe_o    = spi_cr_1[0];


    //============================================================
    // SPI Control Register 2 Bit Mapping
    //============================================================

    assign modfen     = spi_cr_2[4];
    assign spiswai_o  = spi_cr_2[1];


    //============================================================
    // SPI Baud Rate Register Bit Mapping
    //============================================================

    assign sppr_o = spi_br[6:4];
    assign spr_o  = spi_br[2:0];


    //============================================================
    // APB Access Control
    //============================================================

    // Write and read accesses are valid during the APB ENABLE phase.
    assign wr_enb = pwrite_i && (state == enable);
    assign rd_enb = !pwrite_i && (state == enable);

    // The slave indicates that it has completed the APB transfer.
    assign pready_o = (state == enable);


    //============================================================
    // APB Address and Access Error Detection
    //============================================================

    // Valid register addresses:
    //
    // 000 : SPI_CR1  - Read/Write
    // 001 : SPI_CR2  - Read/Write
    // 010 : SPI_BR   - Read/Write
    // 011 : SPI_SR   - Read Only
    // 100 : Reserved
    // 101 : SPI_DR   - Read/Write
    // 110 : Reserved
    // 111 : Reserved

    assign valid_addr = (paddr_i == 3'b000) ||
                        (paddr_i == 3'b001) ||
                        (paddr_i == 3'b010) ||
                        (paddr_i == 3'b011) ||
                        (paddr_i == 3'b101);

    // SPI_SR is a read-only register.
    // A write access to this register generates an APB error.
    assign write_readonly_reg = pwrite_i && (paddr_i == 3'b011);

    // PSLVERR is asserted only during an APB ENABLE phase
    // when the requested address is invalid or a write is
    // attempted on the read-only SPI_SR register.
    assign pslverr_o = (state == enable) &&
                       (!valid_addr || write_readonly_reg);


    //============================================================
    // SPI Operating Mode State Register
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            spi_mode_o <= spi_run;
        else
            spi_mode_o <= next_mode;
    end


    //============================================================
    // SPI Operating Mode State Machine
    //============================================================

    always @(*)
    begin
        case (spi_mode_o)

            spi_run:
            begin
                if (!spe)
                    next_mode = spi_wait;
                else
                    next_mode = spi_run;
            end

            spi_wait:
            begin
                if (spe)
                    next_mode = spi_run;
                else if (spiswai_o)
                    next_mode = spi_stop;
                else
                    next_mode = spi_wait;
            end

            spi_stop:
            begin
                if (spe)
                    next_mode = spi_run;
                else if (!spiswai_o)
                    next_mode = spi_wait;
                else
                    next_mode = spi_stop;
            end

            default:
                next_mode = spi_run;

        endcase
    end


    //============================================================
    // APB State Register
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            state <= idle;
        else
            state <= next_state;
    end


    //============================================================
    // APB State Machine
    //
    // IDLE   -> Wait for PSEL
    // SETUP  -> Address and control information are presented
    // ENABLE -> Complete the APB transfer
    //============================================================

    always @(*)
    begin
        case (state)

            idle:
            begin
                if (psel_i && !penable_i)
                    next_state = setup;
                else
                    next_state = idle;
            end

            setup:
            begin
                if (psel_i && penable_i)
                    next_state = enable;
                else if (psel_i && !penable_i)
                    next_state = setup;
                else
                    next_state = idle;
            end

            enable:
            begin
                if (psel_i)
                    next_state = setup;
                else
                    next_state = idle;
            end

            default:
                next_state = idle;

        endcase
    end


    //============================================================
    // SPI Control Register 1
    //
    // Address: 3'b000
    // Access : Read/Write
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            spi_cr_1 <= 8'h04;
        else if (wr_enb)
        begin
            if (paddr_i == 3'b000)
                spi_cr_1 <= pwdata_i;
        end
    end


    //============================================================
    // SPI Control Register 2
    //
    // Address: 3'b001
    // Access : Read/Write
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            spi_cr_2 <= 8'h00;
        else if (wr_enb)
        begin
            if (paddr_i == 3'b001)
                spi_cr_2 <= pwdata_i & cr2_mask;
        end
    end


    //============================================================
    // SPI Baud Rate Register
    //
    // Address: 3'b010
    // Access : Read/Write
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            spi_br <= 8'h00;
        else if (wr_enb)
        begin
            if (paddr_i == 3'b010)
                spi_br <= pwdata_i & br_mask;
        end
    end


    //============================================================
    // SPI Data Register
    //
    // Address: 3'b101
    // Access : Read/Write
    //
    // The register is loaded with APB write data when a write
    // transaction is performed. During an SPI receive operation,
    // received MISO data is loaded into this register.
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            spi_dr <= 8'b0;

        else if (wr_enb)
        begin
            if (paddr_i == 3'b101)
                spi_dr <= pwdata_i;
        end

        else
        begin
            // Clear the data register after the transmit data
            // has been consumed by the SPI transfer.
            if ((spi_dr == pwdata_i) &&
                (spi_dr != miso_data_i) &&
                ((spi_mode_o == spi_run) || (spi_mode_o == spi_wait)))
            begin
                spi_dr <= 8'b0;
            end

            // Store received MISO data after an SPI transfer.
            else if (((spi_mode_o == spi_run) ||
                      (spi_mode_o == spi_wait)) &&
                      receive_data_i)
            begin
                spi_dr <= miso_data_i;
            end
        end
    end


    //============================================================
    // SPI Status Register
    //
    // SPI_SR is a read-only register.
    //
    // Bit 5 : SPIF  - SPI transfer complete flag
    // Bit 4 :       - Reserved
    // Bit 3 : SPTEF - SPI transmit buffer empty flag
    // Bit 2 : MODF  - SPI mode fault flag
    // Bits 1:0 :    - Reserved
    //============================================================

    always @(*)
    begin
        if (!preset_n)
            spi_sr = 8'b0010_0000;
        else
            spi_sr = {spif, 1'b0, sptef, modf, 4'b0};
    end


    //============================================================
    // SPI Status Flags
    //============================================================

    // SPTEF is set when the SPI data register is empty.
    assign sptef = (spi_dr == 8'b0);

    // SPIF is set when the SPI data register contains data.
    assign spif = (spi_dr != 8'b0);

    // MODF indicates a mode fault when the master detects an
    // invalid slave-select condition.
    assign modf = !ss_i && mstr_o && modfen && !ssoe;


    //============================================================
    // SPI Transmit Request
    //============================================================

    // A transmit request is generated when valid transmit data
    // is detected in the SPI data register.
    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            send_data_o <= 1'b0;

        else if (wr_enb)
            send_data_o <= 1'b0;

        else if ((spi_dr == pwdata_i) &&
                 (spi_dr != miso_data_i) &&
                 ((spi_mode_o == spi_run) ||
                  (spi_mode_o == spi_wait)))
        begin
            send_data_o <= 1'b1;
        end

        else
            send_data_o <= 1'b0;
    end


    //============================================================
    // MOSI Transmit Data
    //============================================================

    // Provides the transmit data to the SPI shift register.
    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            mosi_data_o <= 8'b0;

        else if ((spi_dr == pwdata_i) &&
                 (spi_dr != miso_data_i) &&
                 ((spi_mode_o == spi_run) ||
                  (spi_mode_o == spi_wait)))
        begin
            mosi_data_o <= spi_dr;
        end
    end


    //============================================================
    // APB Read Data Multiplexer
    //
    // Returns the selected register value during an APB read.
    // Reserved addresses return zero.
    //============================================================

    always @(*)
    begin
        if (rd_enb)
        begin
            case (paddr_i)

                3'd0: prdata_o = spi_cr_1;
                3'd1: prdata_o = spi_cr_2;
                3'd2: prdata_o = spi_br;
                3'd3: prdata_o = spi_sr;
                3'd4: prdata_o = 8'b0;
                3'd5: prdata_o = spi_dr;
                3'd6: prdata_o = 8'b0;
                3'd7: prdata_o = 8'b0;

                default:
                    prdata_o = 8'b0;

            endcase
        end

        else
            prdata_o = 8'b0;
    end


    //============================================================
    // SPI Interrupt Request
    //
    // SPIE  : SPI interrupt enable
    // SPTIE : SPI transmit interrupt enable
    // SPIF  : SPI transfer complete flag
    // SPTEF : SPI transmit buffer empty flag
    // MODF  : SPI mode fault flag
    //============================================================

    always @(*)
    begin
        if (!spie && !sptie)
            spi_interrupt_request_o = 1'b0;

        else if (!sptie && spie)
            spi_interrupt_request_o = spif | modf;

        else if (!spie && sptie)
            spi_interrupt_request_o = sptef;

        else
            spi_interrupt_request_o = spif | modf | sptef;
    end


endmodule
