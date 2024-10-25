`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    01:16:44 08/23/2024 
// Design Name: 
// Module Name:    Top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Top(
	input wire [7:0]rxn,
	input wire [7:0]rxp,
	output wire [0:7]txn,
	output wire [0:7]txp,
	
	output reg [0:7]led_fp,
	
	input wire clk160p,
	input wire clk160n,
		   
	input wire clk40p,
	input wire clk40n,
		   
	input wire reset,
	input wire inject,
	//output wire slow_clk40,
	//output wire clk40,
	input wire   [50:0] _ccb_rx
	//output 	wire txusrclk2,
	//output wire [0:7]PRBS_error,
	//output wire [0:4] state_status
	
    );
	wire slow_clk40;
	wire clk40;
	wire txusrclk2;
	wire [0:7]PRBS_error;
	wire [0:4] state_status;
	
	reg PRBS_error_inject;
	// parameter setting
	parameter   WRAPPER_SIM_GTXRESET_SPEEDUP    = 0;    // Set to 1 to speed up sim reset
	wire [0:2] PRBS_mode;
	assign PRBS_mode = 3'b100;// 000: Standard operation mode (PRBS check is off)
								 // 001: PRBS-7
								 // 010: PRBS-15
								 // 011: PRBS-23
								 // 100: PRBS-31
								
	//  Static signal Assigments    
    assign tied_to_ground_i             = 1'b0;
    assign tied_to_ground_vec_i         = 64'h0000000000000000;
    assign tied_to_vcc_i                = 1'b1;
    assign tied_to_vcc_vec_i            = 8'hff;
	
	// GTX clock
	wire q1_clk1_refclk_i;
	
	// misc wire
	wire q1_clk1_refclk_i_bufg;
	
	//wire clk40;
	

	wire txoutclk;

	wire [0:7] tx_reset_done;
	wire [0:7] rx_reset_done;
	//wire [0:7] PRBS_error;
	wire [0:31] counter_out;

	
	// temp tie off
	
	// misc reg
	reg PRBS_reset;
	
	reg boot_up_counter_rst;
	reg [0:7] full_tx_reset;
	reg [0:7] full_rx_reset;
	reg [0:7] latched_error;	
	reg [0:7] blinker;
	reg PRBS_counter_reset;

	// Deal with ccb
	
	reg   [33:0]  ccb_rx_iobff_a = {34{1'b1}}; // synthesis attribute IOB of ccb_rx_iobff_a is "true";
	reg   [50:36] ccb_rx_iobff_b = {15{1'b1}}; // synthesis attribute IOB of ccb_rx_iobff_b is "true";
	wire [50:0]   ccb_rx;
	wire [50:0]   ccb_rx_iobff;
	
	always @(posedge clk40) begin
		ccb_rx_iobff_a[33:0]  <= _ccb_rx[33:0];
		ccb_rx_iobff_b[50:36] <= _ccb_rx[50:36];
	end
	assign ccb_rx_iobff = {~ccb_rx_iobff_b[50:36],2'b00,~ccb_rx_iobff_a[33:0]};
	assign ccb_rx[50:0] = ccb_rx_iobff;
	
	wire  [7:0]      ccb_cmd;
	assign ccb_cmd[5:0] = ccb_rx[7:2];
	assign  ccb_cmd_strobe =  ccb_rx[10];
	assign  ccb_evcntres    =  ccb_rx[ 8];
	assign  ccb_bcntres      =  ccb_rx[ 9];
	assign ccb_cmd[7]     =  ccb_bcntres;  // don't use for cmd decoding
	assign ccb_cmd[6]     =  ccb_evcntres;  // don't use for cmd decoding

	
	integer i;
	parameter MXDEC = 'h32;    // Highest CCB Command decode
	reg  [MXDEC:0] ccb_cmd_dec =0;
	
	always @(posedge clk40) begin
		i=0;
		while (i<=MXDEC)
		begin
		ccb_cmd_dec[i] <= (ccb_cmd[5:0]==i) && ccb_cmd_strobe;
		i=i+1;
		end
	end
	
	wire ttc_bx0_dec        = ccb_cmd_dec['h01];  // Bunch Crossing Zero   
	wire ttc_resync          = ccb_cmd_dec['h03];  // Reset L1 readout buffers and resynchronize optical links  
	wire ttc_bxreset        = ccb_cmd_dec['h32];  // Resets bxn, does not reset l1a count or buffers	

	reg ttc_bx0_dec_sync1;
	reg ttc_resync_sync1;
	reg ttc_bxreset_sync1;
	
	reg ttc_bx0_dec_sync;
	reg ttc_resync_sync;
	reg ttc_bxreset_sync;
	
	// Cross time domain sync, go from Clk40 to txusrclk2
	always @(posedge txusrclk2)
	begin
	
	ttc_bx0_dec_sync1 <= ttc_bx0_dec;
	ttc_resync_sync1  <= ttc_resync ;
	ttc_bxreset_sync1 <=  ttc_bxreset;
	 
    ttc_bx0_dec_sync  <= ttc_bx0_dec_sync1;
	ttc_resync_sync   <= ttc_resync_sync1;
	ttc_bxreset_sync  <= ttc_bxreset_sync1;
	
	end
	IBUFDS #(
		.DIFF_TERM("FALSE"),       // Differential Termination
		.IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE"
		.IOSTANDARD("LVDS_25")     // Specify the input I/O standard
	)QPLL_to_clk40
    (
        .O                              (clk40),
        .I                              (clk40p),  // Connect to LVDS p
        .IB                             (clk40n)  // Connect to LVDS n
    );
	
	always@(posedge slow_clk40)
	begin
		blinker = ~blinker;
	end

	clock_divider clk40_display(clk40,slow_clk40);
	// counter
	counter boot_up_counter(slow_clk40,
			boot_up_counter_rst,
			counter_out);
	
	wire  [0:1]error_counter_out_0;
	wire  [0:1]error_counter_out_1;
	wire  [0:1]error_counter_out_2;
	wire  [0:1]error_counter_out_3;
	
	counter_noover counter_noover_0(.clk(txusrclk2),.enable(PRBS_error[4]),.rst(PRBS_counter_reset),.out(error_counter_out_0[0:1]));
	counter_noover counter_noover_1(.clk(txusrclk2),.enable(PRBS_error[5]),.rst(PRBS_counter_reset),.out(error_counter_out_1[0:1]));
	counter_noover counter_noover_2(.clk(txusrclk2),.enable(PRBS_error[6]),.rst(PRBS_counter_reset),.out(error_counter_out_2[0:1]));
	counter_noover counter_noover_3(.clk(txusrclk2),.enable(PRBS_error[7]),.rst(PRBS_counter_reset),.out(error_counter_out_3[0:1]));
	// boot state machine
	localparam RESET	           = 4'd0;
	localparam EN_TX     	     = 4'd1;    
	localparam EN_TX_DONE     	  = 4'd2;
	localparam EN_RX             = 4'd3;
	localparam EN_RX_DONE        = 4'd4;
	localparam PRBS_INJECT 	     = 4'd5;
	localparam PRBS_INJECT_DONE  = 4'd6;
	localparam PRBS_INJECT_CLEAR = 4'd7;
	localparam EN_PRBS_CK        = 4'd8;
	
	reg [0:4] state, nxtState;
	assign state_status = state;
	// reset 
    always @ (posedge clk40 or posedge ttc_resync_sync)
		if (reset|ttc_resync_sync)
			state <= RESET;
		else
			state <= nxtState;
	
	always @(*) begin
		nxtState <= state; // Default next state: don’t move
		case (state)
			RESET : begin
				nxtState <= EN_TX;
				
				PRBS_reset <= 1'b0;
				boot_up_counter_rst <= 1'b1;
				PRBS_counter_reset <= 1'b1;
				full_tx_reset[0:7] <= 8'b1111_1111;
				full_rx_reset[0:7] <= 8'b1111_1111;

				led_fp[0:7] <= 8'b001_0000;
			end 
			EN_TX : begin
				if (counter_out >= 32'd20)
					nxtState <= EN_TX_DONE;
				
				PRBS_reset <= 1'b0;
				boot_up_counter_rst <= 1'b0;
				PRBS_counter_reset <= 1'b1;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b1111_1111;
				led_fp[0:7] <= 8'b0010_0000;
			end
			EN_TX_DONE : begin
				if (tx_reset_done == 8'b1111_1111)
					nxtState <= EN_RX;
				
				PRBS_reset <= 1'b0;
				boot_up_counter_rst <= 1'b1;
				PRBS_counter_reset <= 1'b1;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b1111_1111;
				led_fp[0:7] <= 8'b0011_0000;
			end
			EN_RX : begin
				if (counter_out >= 32'd40)
					nxtState <= EN_RX_DONE;
				
				PRBS_reset <= 1'b0;
				boot_up_counter_rst <= 1'b0;
				PRBS_counter_reset <= 1'b1;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b0000_0000;
				led_fp[0:7] <= 8'b0100_0000;
			end
			EN_RX_DONE : begin
				if (rx_reset_done == 8'b1111_1111)
					nxtState <= PRBS_INJECT;
				
				PRBS_reset <= 1'b0;
				PRBS_error_inject <= 1'b1;
				PRBS_counter_reset <= 1'b1;
				boot_up_counter_rst <= 1'b1;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b0000_0000;
				led_fp[0:7] <= 8'b0101_0000;
			end
			PRBS_INJECT :  begin
				if (counter_out >= 32'd140)
					nxtState <= PRBS_INJECT_DONE;
				
				PRBS_reset <= 1'b0;
				PRBS_error_inject <= 1'b1;
				PRBS_counter_reset <= 1'b1;
				boot_up_counter_rst <= 1'b0;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b0000_0000;
				led_fp[0:3] <= 4'b0110;
				led_fp[4:7] <= latched_error[4:7] | blinker[4:7];
			end
			
			PRBS_INJECT_DONE :  begin
				if (counter_out >= 32'd160)
					nxtState <= PRBS_INJECT_CLEAR;
				
				PRBS_reset <= 1'b1;
				PRBS_error_inject <= 1'b1;
				PRBS_counter_reset <= 1'b1;
				boot_up_counter_rst <= 1'b0;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b0000_0000;
				led_fp[0:3] <= 4'b1000;
				led_fp[4:7] <= latched_error[4:7] | blinker[4:7];
			end
			
			PRBS_INJECT_CLEAR :  begin
				if(counter_out >= 32'd180) 
					nxtState <= EN_PRBS_CK;
				
				PRBS_reset <= 1'b0;
				PRBS_counter_reset <= 1'b1;
				PRBS_error_inject <= 1'b0;
				boot_up_counter_rst <= 1'b0;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b0000_0000;
				led_fp[0:3] <= 4'b0111;
				led_fp[4:7] <= latched_error[4:7] | blinker[4:7];
			end
			
			EN_PRBS_CK : begin
				nxtState <= EN_PRBS_CK;
				
				PRBS_reset <= 1'b0|ttc_bxreset_sync;
				PRBS_counter_reset <= 1'b0|ttc_bxreset_sync;
				boot_up_counter_rst <= 1'b1;
				full_tx_reset[0:7] <= 8'b0000_0000;
				full_rx_reset[0:7] <= 8'b0000_0000;
				PRBS_error_inject <= inject|ttc_bx0_dec_sync; //connect to inject later
				//led_fp[0:3] <= 4'b1010;
				//led_fp[4:7] <= latched_error[4:7] | blinker[4:7];
				led_fp[0:1] <= error_counter_out_0[0:1] | blinker[0:1];
				led_fp[2:3] <= error_counter_out_1[0:1] | blinker[0:1];
				led_fp[4:5] <= error_counter_out_2[0:1] | blinker[0:1];
				led_fp[6:7] <= error_counter_out_3[0:1] | blinker[0:1]; 
			end
				default : begin
				nxtState <= RESET;
				PRBS_reset <= 1'b0;
				PRBS_counter_reset <= 1'b0;
				boot_up_counter_rst <= 1'b1;
				PRBS_error_inject <= 1'b0;
				full_tx_reset[0:7] <= 8'b1111_1111;
				full_rx_reset[0:7] <= 8'b1111_1111;
				led_fp[0:7] <= 8'b0000_0000;
			end
		endcase
	end
	
	always@(posedge txusrclk2 or posedge PRBS_reset) begin
		if (PRBS_reset)
			latched_error[0:7] <= 8'b0000_0000;
		else
			latched_error[0:7] <= PRBS_error[0:7] | latched_error[0:7];
	end
	
		
	//---------------------Dedicated GTX Reference Clock Inputs ---------------
    // Each dedicated refclk you are using in your design will need its own IBUFDS_GTXE1 instance
    // BUFG can be added
    IBUFDS_GTXE1 q1_clk1_refclk_ibufds_i
    (
        .O                              (q1_clk1_refclk_i),
        .ODIV2                          (),
        .CEB                            (tied_to_ground_i),
        .I                              (clk160p),  // Connect to package pin AB6
        .IB                             (clk160n)  // Connect to package pin AB5
    ); 
	
	    BUFG q1_clk1_refclk_bufg_i
    (
        .I                              (q1_clk1_refclk_i),
        .O                              (q1_clk1_refclk_i_bufg)
    );

	
	//--------------------------------- User Clocks ---------------------------
    
    // The clock resources in this section were added based on userclk source selections on
    // the Latency, Buffering, and Clocking page of the GUI. A few notes about user clocks:
    // * The userclk and userclk2 for each GTX datapath (TX and RX) must be phase aligned to 
    //   avoid data errors in the fabric interface whenever the datapath is wider than 10 bits
    // * To minimize clock resources, you can share clocks between GTXs. GTXs using the same frequency
    //   or multiples of the same frequency can be accomadated using MMCMs. Use caution when
    //   using RXRECCLK as a clock source, however - these clocks can typically only be shared if all
    //   the channels using the clock are receiving data from TX channels that share a reference clock 
    //   source with each other.

    BUFG txoutclk_bufg0_i
    (
        .I                              (txoutclk),
        .O                              (txusrclk2)
    );
	
    //GTX0  (X0Y0) f1 rx0
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx0_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[0]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[0]),
        .RXP_IN                         (rxp[0]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[0]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[0]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (txoutclk),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (),
        .TXP_OUT                        (),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (tied_to_ground_i),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );
	
	//GTX1  (X0Y1) f2 rx1
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx1_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[1]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[1]),
        .RXP_IN                         (rxp[1]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[1]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[1]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (),
        .TXP_OUT                        (),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (tied_to_ground_i),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );

	//GTX2  (X0Y2) f3 rx2 f12 tx2
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx2_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[2]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[2]),
        .RXP_IN                         (rxp[2]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[2]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[2]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[7]),
        .TXP_OUT                        (txp[7]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[7]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[7]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );
	
	//GTX3  (X0Y3) f4 rx3 f1 tx3
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx3_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[3]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[3]),
        .RXP_IN                         (rxp[3]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[3]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[3]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[0]),
        .TXP_OUT                        (txp[0]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[0]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[0]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );

	//GTX4  (X0Y4) f rx4 f2 tx4
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx4_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (tied_to_ground_vec_i),
        .RXP_IN                         (tied_to_ground_vec_i),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (tied_to_ground_i),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[1]),
        .TXP_OUT                        (txp[1]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[1]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[1]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );
	
	//GTX7  (X0Y7) fNONE rx7 f3 tx7
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx7_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (tied_to_ground_vec_i),
        .RXP_IN                         (tied_to_ground_vec_i),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (tied_to_ground_i),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[2]),
        .TXP_OUT                        (txp[2]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[2]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[2]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );
	
	//GTX8  (X0Y8) f9 rx8 f8 tx8
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx8_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[4]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[4]),
        .RXP_IN                         (rxp[4]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[4]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[4]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[3]),
        .TXP_OUT                        (txp[3]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[3]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[3]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );
	//GTX9  (X0Y9) f10 rx9 f9 tx9
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx9_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[5]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[5]),
        .RXP_IN                         (rxp[5]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[5]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[5]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_ground_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[4]),
        .TXP_OUT                        (txp[4]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[4]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[4]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );
	//GTX10  (X0Y10) f11 rx10 f10 tx10
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx10_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[6]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[6]),
        .RXP_IN                         (rxp[6]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[6]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[6]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_ground_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[5]),
        .TXP_OUT                        (txp[5]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[5]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[5]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );
	
	//GTX11  (X0Y11) f12 rx11 f11 tx11
    Fiber_gtx #
    (
        // Simulation attributes
        .GTX_SIM_GTXRESET_SPEEDUP   (WRAPPER_SIM_GTXRESET_SPEEDUP),
        
        // Share RX PLL parameter
        .GTX_TX_CLK_SOURCE           ("TXPLL"),
        // Save power parameter
        .GTX_POWER_SAVE              (10'b0000110000)
    )
    gtx11_Fiber_i
    (
        //--------------------- Receive Ports - PRBS Detection ---------------------
        .PRBSCNTRESET_IN                (PRBS_reset),
        .RXENPRBSTST_IN                 (PRBS_mode),
        .RXPRBSERR_OUT                  (PRBS_error[7]),
        //----------------- Receive Ports - RX Data Path interface -----------------
        .RXDATA_OUT                     (),
        .RXUSRCLK2_IN                   (txusrclk2),
        //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        .RXN_IN                         (rxn[7]),
        .RXP_IN                         (rxp[7]),
        //---------------------- Receive Ports - RX PLL Ports ----------------------
        .GTXRXRESET_IN                  (full_rx_reset[7]),
        .MGTREFCLKRX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLRXRESET_IN                  (tied_to_ground_i),
        .RXPLLLKDET_OUT                 (),
        .RXRESETDONE_OUT                (rx_reset_done[7]),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .RXPOLARITY_IN                  (tied_to_vcc_i), // inverted based on the IBERT test
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .TXDATA_IN                      (tied_to_ground_i),
        .TXOUTCLK_OUT                   (),
        .TXUSRCLK2_IN                   (txusrclk2),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .TXN_OUT                        (txn[6]),
        .TXP_OUT                        (txp[6]),
        //--------------------- Transmit Ports - TX PLL Ports ----------------------
        .GTXTXRESET_IN                  (full_tx_reset[6]),
        .MGTREFCLKTX_IN                 ({tied_to_ground_i , q1_clk1_refclk_i}),
        .PLLTXRESET_IN                  (tied_to_ground_i),
        .TXPLLLKDET_OUT                 (),
        .TXRESETDONE_OUT                (tx_reset_done[6]),
        //------------------- Transmit Ports - TX PRBS Generator -------------------
        .TXENPRBSTST_IN                 (PRBS_mode),
        .TXPRBSFORCEERR_IN              (PRBS_error_inject),
        //------------------ Transmit Ports - TX Polarity Control ------------------
        .TXPOLARITY_IN                  (tied_to_ground_i)

    );

endmodule
