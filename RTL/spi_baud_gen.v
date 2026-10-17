//------------------------------------------------------------------------------
// Module Name : spi_baud_gen
//
// Description :
// Generates the SPI serial clock and timing events used by the SPI shift
// register.
//
// The SPI clock frequency is controlled by the SPPR and SPR configuration
// fields:
//
//     Baud Rate Divisor = (SPPR + 1) * 2^(SPR + 1)
//
// The block also generates transmit and receive timing pulses according to
// the selected CPOL and CPHA configuration.
//
// spi_mode_i:
//   2'b00 : SPI RUN
//   2'b01 : SPI WAIT
//   2'b10 : SPI STOP
//------------------------------------------------------------------------------

module spi_baud_gen(
    input        pclk,
    input        preset_n,
    input        spiswai_i,
    input        cpol_i,
    input        cpha_i,
    input        ss_i,
    input  [1:0] spi_mode_i,
    input  [2:0] sppr_i,
    input  [2:0] spr_i,

    output reg   sclk_o,
    output reg   miso_receive_sclk_o,
    output reg   miso_receive_sclk0_o,
    output reg   mosi_send_sclk_o,
    output reg   mosi_send_sclk0_o,

    output [11:0] baudratedivisor
);

    wire pre_sclk_s;
    reg  [11:0] count_s;

    //--------------------------------------------------------------------------
    // Baud-rate divisor calculation
    //--------------------------------------------------------------------------

    assign baudratedivisor = (sppr_i + 1) * (2 ** (spr_i + 1));

    // SPI clock starts from the configured CPOL value.
    assign pre_sclk_s = cpol_i ? 1'b1 : 1'b0;

    //--------------------------------------------------------------------------
    // SPI clock generation
    //
    // SCLK toggles after half of the configured baud-rate divisor.
    // The clock remains at CPOL when no SPI transfer is active.
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            count_s <= 12'b0;
            sclk_o  <= pre_sclk_s;
        end
        else if (!ss_i &&
                 !spiswai_i &&
                 ((spi_mode_i == 2'b00) || (spi_mode_i == 2'b01)))
        begin
            if (count_s == (baudratedivisor / 2) - 1)
            begin
                count_s <= 12'b0;
                sclk_o  <= ~sclk_o;
            end
            else
            begin
                count_s <= count_s + 1'b1;
            end
        end
        else
        begin
            count_s <= 12'b0;
        end
    end

    //--------------------------------------------------------------------------
    // MISO receive timing generation
    //
    // The selected timing pulse determines when the shift register samples
    // the MISO input.
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            miso_receive_sclk_o  <= 1'b0;
            miso_receive_sclk0_o <= 1'b0;
        end
        else
        begin
            // Default values make the timing signals one-clock-cycle pulses.
            miso_receive_sclk_o  <= 1'b0;
            miso_receive_sclk0_o <= 1'b0;

            if ((!cpha_i && cpol_i) || (cpha_i && !cpol_i))
            begin
                if (sclk_o && (count_s == (baudratedivisor / 2) - 1))
                    miso_receive_sclk0_o <= 1'b1;
            end
            else if ((!cpha_i && !cpol_i) || (cpha_i && cpol_i))
            begin
                if (!sclk_o && (count_s == (baudratedivisor / 2) - 1))
                    miso_receive_sclk_o <= 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // MOSI transmit timing generation
    //
    // The transmit pulse occurs one PCLK count before the corresponding
    // receive timing event.
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            mosi_send_sclk_o  <= 1'b0;
            mosi_send_sclk0_o <= 1'b0;
        end
        else
        begin
            mosi_send_sclk_o  <= 1'b0;
            mosi_send_sclk0_o <= 1'b0;

            if ((!cpha_i && cpol_i) || (cpha_i && !cpol_i))
            begin
                if (sclk_o && (count_s == (baudratedivisor / 2) - 2))
                    mosi_send_sclk0_o <= 1'b1;
            end
            else if ((!cpha_i && !cpol_i) || (cpha_i && cpol_i))
            begin
                if (!sclk_o && (count_s == (baudratedivisor / 2) - 2))
                    mosi_send_sclk_o <= 1'b1;
            end
        end
    end

endmodule