`timescale 1ns / 1ps

module skeleton_top_fsm (
    input wire clk,
    input wire pbin,
    input wire [15:0] physical_sw,
    output wire [15:0] physical_leds
);
    // DEBOUNCER
    wire rst_clean;
    wire [31:0] switch_data;
    reg [31:0] led_write_data = 32'd0;
    wire slow_en;

    debouncer rst_db (
        .clk(clk),
        .pbin(pbin),
        .pbout(rst_clean) // clean signal
    );

    leds switch_reader (
        .clk(clk),
        .rst(rst_clean),
        .btns(16'd0),
        .writeData(32'd0),
        .writeEnable(1'b0),
        .readEnable(1 me'b1),
        .memAddress(30'd0),
        .switches(physical_sw),
        .readData(switch_data)
    );

    switches led_writer (
        .clk(clk),
        .rst(rst_clean),
        .writeData(led_write_data),
        .writeEnable(1'b1),
        .readEnable(1'b0),
        .memAddress(30'd0),
        .readData(),
        .leds(physical_leds)
    );

    clock_divider ticker (
        .clk_in(clk),
        .rst(rst_clean),
        .clk_en(slow_en)
    );

    // State definitions
    parameter INPUT_WAITING = 2'b00;
    parameter COUNTDOWN     = 2'b01;
    parameter RESET_STATE   = 2'b10;

    reg [1:0] state = INPUT_WAITING;
    reg [31:0] counter = 32'd0;

    always @(posedge clk) begin
        if (rst_clean) begin
            // Enter Reset State while reset button is held
            state <= RESET_STATE;
            counter <= 32'd0;
            led_write_data <= 32'd0;
        end else begin
            case (state)
                RESET_STATE: begin
                    // Button released (rst_clean == 0), move to INPUT_WAITING
                    state <= INPUT_WAITING;
                end

                INPUT_WAITING: begin
                    // Wait for nonzero input from switches
                    if (switch_data != 32'd0) begin
                        counter <= switch_data;
                        led_write_data <= switch_data; // Latch initial value to LEDs
                        state <= COUNTDOWN;
                    end
                end

                COUNTDOWN: begin
                    // Decrement when slow clock tick fires
                    if (slow_en) begin
                        if (counter > 32'd1) begin
                            counter <= counter - 1;
                            led_write_data <= counter - 1;
                        end else begin
                            // Counter hits zero: clear outputs and return directly to INPUT_WAITING
                            counter <= 32'd0;
                            led_write_data <= 32'd0;
                            state <= INPUT_WAITING;
                        end
                    end
                end

                default: state <= INPUT_WAITING;
            endcase
        end
    end
endmodule
