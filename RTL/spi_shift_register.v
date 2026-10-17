//------------------------------------------------------------------------------
// Module Name : spi_shift_register
//
// Description :
// Handles SPI serial data transmission and reception.
//
// Transmit path:
//   - Loads an 8-bit parallel value from data_mosi_i.
//   - Sends the data serially through MOSI.
//   - Supports MSB-first and LSB-first transfers.
//
// Receive path:
//   - Samples the MISO input using timing pulses from the baud generator.
//   - Stores the received bits in temp_reg.
//   - Provides the completed 8-bit value through data_miso_o.
//
// CPOL/CPHA determine which timing pulse is used for transmit and receive.
//------------------------------------------------------------------------------

module spi_shift_register(
    input        pclk,
    input        preset_n,
    input        ss_i,
    input        send_data_i,
    input        lsbfe_i,
    input        cpha_i,
    input        cpol_i,

    input        miso_receive_sclk,
    input        miso_receive_sclk0,
    input        mosi_send_sclk,
    input        mosi_send_sclk0,

    input        miso_i,
    input        receive_data_i,
    input  [7:0] data_mosi_i,

    output reg   mosi_o,
    output [7:0] data_miso_o
);

    //--------------------------------------------------------------------------
    // Internal shift and receive registers
    //--------------------------------------------------------------------------

    reg [7:0] shift_reg;
    reg [7:0] temp_reg;

    // Bit counters for MSB-first and LSB-first operation.
    reg [2:0] count;
    reg [2:0] count1;
    reg [2:0] count2;
    reg [2:0] count3;

    //--------------------------------------------------------------------------
    // Parallel load of transmit data
    //
    // The APB interface provides the transmit data through data_mosi_i.
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            shift_reg <= 8'b0;
        else if (send_data_i)
            shift_reg <= data_mosi_i;
    end

    // Received data is exposed after the receive operation is completed.
    assign data_miso_o = receive_data_i ? temp_reg : 8'b0;

    //--------------------------------------------------------------------------
    // SPI MOSI generation
    //
    // The timing signal used depends on the CPOL/CPHA configuration.
    // LSBFE selects the direction in which bits are transmitted.
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            mosi_o <= 1'b0;
            count  <= 3'd0;
            count1 <= 3'd7;
        end
        else if (!ss_i)
        begin
            // SPI configurations using the negative-edge transmit event.
            if ((!cpha_i && cpol_i) || (cpha_i && !cpol_i))
            begin
                if (lsbfe_i)
                begin
                    if (count <= 3'd7)
                    begin
                        if (mosi_send_sclk0)
                        begin
                            mosi_o <= shift_reg[count];
                            count  <= count + 1'b1;
                        end
                    end
                    else
                        count <= 3'd0;
                end
                else
                begin
                    if (count1 >= 3'd0)
                    begin
                        if (mosi_send_sclk0)
                        begin
                            mosi_o <= shift_reg[count1];
                            count1 <= count1 - 1'b1;
                        end
                    end
                    else
                        count1 <= 3'd7;
                end
            end

            // SPI configurations using the positive-edge transmit event.
            else if ((!cpha_i && !cpol_i) || (cpha_i && cpol_i))
            begin
                if (lsbfe_i)
                begin
                    if (count <= 3'd7)
                    begin
                        if (mosi_send_sclk)
                        begin
                            mosi_o <= shift_reg[count];
                            count  <= count + 1'b1;
                        end
                    end
                    else
                        count <= 3'd0;
                end
                else
                begin
                    if (count1 >= 3'd0)
                    begin
                        if (mosi_send_sclk)
                        begin
                            mosi_o <= shift_reg[count1];
                            count1 <= count1 - 1'b1;
                        end
                    end
                    else
                        count1 <= 3'd7;
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // SPI MISO sampling
    //
    // The received bit is stored in temp_reg according to the selected
    // bit-order and SPI timing configuration.
    //--------------------------------------------------------------------------

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            temp_reg <= 8'b0;
            count2   <= 3'd0;
            count3   <= 3'd7;
        end
        else if (!ss_i)
        begin
            // SPI configurations using the negative-edge receive event.
            if ((!cpha_i && cpol_i) || (cpha_i && !cpol_i))
            begin
                if (lsbfe_i)
                begin
                    if (count2 <= 3'd7)
                    begin
                        if (miso_receive_sclk0)
                        begin
                            temp_reg[count2] <= miso_i;
                            count2 <= count2 + 1'b1;
                        end
                    end
                    else
                        count2 <= 3'd0;
                end
                else
                begin
                    if (count3 >= 3'd0)
                    begin
                        if (miso_receive_sclk0)
                        begin
                            temp_reg[count3] <= miso_i;
                            count3 <= count3 - 1'b1;
                        end
                    end
                    else
                        count3 <= 3'd7;
                end
            end

            // SPI configurations using the positive-edge receive event.
            else if ((!cpha_i && !cpol_i) || (cpha_i && cpol_i))
            begin
                if (lsbfe_i)
                begin
                    if (count2 <= 3'd7)
                    begin
                        if (miso_receive_sclk)
                        begin
                            temp_reg[count2] <= miso_i;
                            count2 <= count2 + 1'b1;
                        end
                    end
                    else
                        count2 <= 3'd0;
                end
                else
                begin
                    if (count3 >= 3'd0)
                    begin
                        if (miso_receive_sclk)
                        begin
                            temp_reg[count3] <= miso_i;
                            count3 <= count3 - 1'b1;
                        end
                    end
                    else
                        count3 <= 3'd7;
                end
            end
        end
    end

endmodule