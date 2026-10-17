//------------------------------------------------------------------------------
// Module Name : spi_slave_control_select
//
// Description :
// Controls the duration of an SPI transaction.
//
// When transmit data(send_data_i) is available, this block:
//   - Activates SS.
//   - Counts the required PCLK cycles for an 8-bit SPI transfer.
//   - Deactivates SS after the transfer.
//   - Generates receive_data_o to indicate completion.
//
// TIP indicates that an SPI transfer is currently active.
//
// The target count is derived from the SPI baud-rate divisor:
//
//     target = (baudratedivisor / 2) * 16
//
// The factor of 16 represents the number of half-SCLK periods required for
// an 8-bit SPI transfer.
//------------------------------------------------------------------------------

module spi_slave_control_select(
    input        pclk,
    input        preset_n,
    input        mstr_i,
    input        spiswai_i,
    input        send_data_i,
    input  [1:0] spi_mode_i,
    input  [11:0] baudratedivisor_i,

    output reg   receive_data_o,
    output reg   ss_o,
    output       tip_o
);

    reg [13:0] count;
    reg        rcv;

    wire [13:0] target;

    parameter spi_run  = 2'b00,
              spi_wait = 2'b01;

    // TIP is asserted while SS is active.
    assign tip_o = ~ss_o;

    // Number of PCLK cycles required for an 8-bit SPI transfer.
    assign target = (baudratedivisor_i / 2) * 16;

    //--------------------------------------------------------------------------
    // Transfer-complete indication
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            receive_data_o <= 1'b0;
        else
            receive_data_o <= rcv;
    end

    //--------------------------------------------------------------------------
    // SPI transfer control
    //
    // SS is asserted when a transfer starts and remains low until the
    // programmed number of SPI clock periods has elapsed.
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            count <= 14'h3FFF;
            ss_o  <= 1'b1;
            rcv   <= 1'b0;
        end
        else if (mstr_i &&
                 ((spi_mode_i == spi_run) ||
                  (spi_mode_i == spi_wait)) &&
                 !spiswai_i)
        begin
            if (send_data_i)
            begin
                count <= 14'd0;
                ss_o  <= 1'b0;
                rcv   <= 1'b0;
            end
            else if (count < target - 1'b1)
            begin
                count <= count + 1'b1;
                ss_o  <= 1'b0;
                rcv   <= 1'b0;
            end
            else
            begin
                count <= 14'h3FFF;
                ss_o  <= 1'b1;
                rcv   <= (count == target - 1'b1);
            end
        end
        else
        begin
            count <= 14'h3FFF;
            ss_o  <= 1'b1;
            rcv   <= 1'b0;
        end
    end

endmodule