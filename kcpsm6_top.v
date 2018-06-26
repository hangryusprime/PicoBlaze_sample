
`timescale 1ps/1ps

module kcpsm6_top(clk,output_port_x,sw,seg);

input clk;
input [7:0] sw;
output [7:0] output_port_x,seg;
wire	[11:0]	address;
wire	[17:0]	instruction;
wire			bram_enable;
wire	[7:0]		port_id;
wire	[7:0]		out_port;
reg	[7:0]		in_port;
reg [7:0] output_port_x,seg;
wire			write_strobe;
wire			k_write_strobe;
wire			read_strobe;
reg			interrupt;            //See note above
wire			interrupt_ack;
wire			kcpsm6_sleep;         //See note above
wire			kcpsm6_reset;         //See note above
wire			rdl;
wire			int_request;

  kcpsm6 #(
	.interrupt_vector	(12'h3FF),
	.scratch_pad_memory_size(64),
	.hwbuild		(8'h00))
  processor (
	.address 		(address),
	.instruction 	(instruction),
	.bram_enable 	(bram_enable),
	.port_id 		(port_id),
	.write_strobe 	(write_strobe),
	.k_write_strobe 	(k_write_strobe),
	.out_port 		(out_port),
	.read_strobe 	(read_strobe),
	.in_port 		(in_port),
	.interrupt 		(interrupt),
	.interrupt_ack 	(interrupt_ack),
	.reset 		(kcpsm6_reset),
	.sleep		(kcpsm6_sleep),
	.clk 			(clk)); 

  assign kcpsm6_sleep = 1'b0;
  initial interrupt = 1'b0;
  assign int_request = 1'b0;

  ROM #(
	.C_FAMILY		   ("S6"),   	//Family 'S6' or 'V6'
	.C_RAM_SIZE_KWORDS	(1),     	//Program size '1', '2' or '4'
	.C_JTAG_LOADER_ENABLE	(1))     	//Include JTAG Loader when set to 1'b1 
  program_rom (    		       	//Name to match your PSM file
 	.rdl 			(rdl),
	.enable 		(bram_enable),
	.address 		(address),
	.instruction 	(instruction),
	.clk 			(clk));
	
  assign kcpsm6_reset = rdl;

  //
  /////////////////////////////////////////////////////////////////////////////////////////
  // Example of General Purose I/O Ports.
  /////////////////////////////////////////////////////////////////////////////////////////
  //
  // The following code corresponds with the circuit diagram shown on page 72 of the 
  // KCPSM6 Guide and includes additional advice and recommendations.
  //
  //

  //
  /////////////////////////////////////////////////////////////////////////////////////////
  // General Purpose Input Ports. 
  /////////////////////////////////////////////////////////////////////////////////////////
  //
  //
  // The inputs connect via a pipelined multiplexer. For optimum implementation, the input
  // selection control of the multiplexer is limited to only those signals of 'port_id' 
  // that are necessary. In this case, only 2-bits are required to identify each of  
  // four input ports to be read by KCPSM6.
  //
  // Note that 'read_strobe' only needs to be used when whatever supplying information to
  // KPPSM6 needs to know when that information has been read. For example, when reading 
  // a FIFO a read signal would need to be generated when that port is read such that the 
  // FIFO would know to present the next oldest information.
  //

  always @ (posedge clk)
  begin

      case (port_id[1:0]) 
      
////////////////        // Read input_port_a at port address 00 hex
////////////////        1'b0 : in_port <= sw;
////////////////        // Read input_port_b at port address 01 hex
////////////////        1'b1 : begin
////////////////		         in_port[0] <= push_n;
////////////////		         in_port[1] <= push_e;
////////////////		         in_port[2] <= push_s;
////////////////		         in_port[3] <= push_w;
////////////////		         in_port[4] <= push_c;
////////////////               end
//////////////////////////////        // Read input_port_c at port address 02 hex
//////////////////////////////        2'b10 : in_port <= input_port_c;
//////////////////////////////
//////////////////////////////        // Read input_port_d at port address 03 hex
//////////////////////////////        2'b11 : in_port <= input_port_d;
////////////////
////////////////        // To ensure minimum logic implementation when defining a multiplexer always
////////////////        // use don't care for any of the unused cases (although there are none in this 
////////////////        // example).

        default : in_port <= sw ;  

      endcase

  end

  //
  /////////////////////////////////////////////////////////////////////////////////////////
  // General Purpose Output Ports 
  /////////////////////////////////////////////////////////////////////////////////////////
  //
  //
  // Output ports must capture the value presented on the 'out_port' based on the value of 
  // 'port_id' when 'write_strobe' is High.
  //
  // For an optimum implementation the allocation of output ports should be made in a way 
  // that means that the decoding of 'port_id' is minimised. Whilst there is nothing 
  // logically wrong with decoding all 8-bits of 'port_id' it does result in a function 
  // that can not fit into a single 6-input look up table (LUT6) and requires all signals 
  // to be routed which impacts size, performance and power consumption of your design.
  // So unless you really have a lot of output ports it is best practice to use 'one-hot'
  // allocation of addresses as used below or to limit the number of 'port_id' bits to 
  // be decoded to the number required to cover the ports.
  // 
  // Code examples in which the port address is 04 hex. 
  //
  // Best practice in which one-hot allocation only requires a single bit to be tested.
  // Supports up to 8 output ports with each allocated a different bit of 'port_id'.
  //
  //   if (port_id[2] == 1'b1)  output_port_x <= out_port;  
  //
  //
  // Limited decode in which 5-bits of 'port_id' are used to identify up to 32 ports and 
  // the decode logic can still fit within a LUT6 (the 'write_strobe' requiring the 6th 
  // input to complete the decode).
  // 
  //   if (port_id[4:0] == 5'b00100) output_port_x <= out_port;
  // 
  //
  // The 'generic' code may be the easiest to write with the minimum of thought but will 
  // result in two LUT6 being used to implement each decoder. This will also impact
  // performance and power. This is not generally a problem and hence it is reasonable to 
  // consider this as over attention to detail but good design practice will often bring 
  // rewards in the long term. When a large design struggles to fit into a given device 
  // and/or meet timing closure then it is often the result of many small details rather 
  // that one big cause. PicoBlaze is extremely efficient so it would be a shame to 
  // spoil that efficiency with unnecessarily large and slow peripheral logic.
  //
  //   if port_id = X"04" then output_port_x <= out_port;  
  //

  always @ (posedge clk)
  begin

      // 'write_strobe' is used to qualify all writes to general output ports.
      if (write_strobe == 1'b1) begin

        // Write to output_port_w at port address 01 hex
        if (port_id[1] == 1'b1) begin
          output_port_x <= out_port;
        end
		  if (port_id[0] == 1'b1) begin
           seg <= out_port;   		  
		  end

        // Write to output_port_x at port address 02 hex
//////////////        if (port_id[1] == 1'b1) begin
//////////////          led_n <= out_port[0];
//////////////			 led_e <= out_port[1];
//////////////			 led_s <= out_port[2];
//////////////			 led_w <= out_port[3];
//////////////			 led_c <= out_port[4];
//////////////        end

//////////////        // Write to output_port_y at port address 04 hex
//////////////        if (port_id[2] == 1'b1) begin
//////////////          output_port_y <= out_port;
//////////////        end
//////////////
//////////////        // Write to output_port_z at port address 08 hex
//////////////        if (port_id[3] == 1'b1) begin
//////////////          output_port_z <= out_port;
//////////////        end

      end

  end
  //
  /////////////////////////////////////////////////////////////////////////////////////////
  // Constant-Optimised Output Ports 
  /////////////////////////////////////////////////////////////////////////////////////////
  //
  //
  // Implementation of the Constant-Optimised Output Ports should follow the same basic 
  // concepts as General Output Ports but remember that only the lower 4-bits of 'port_id'
  // are used and that 'k_write_strobe' is used as the qualifier.
  //

//////////////  always @ (posedge clk)
//////////////  begin
//////////////
//////////////      // 'k_write_strobe' is used to qualify all writes to constant output ports.
//////////////      if (k_write_strobe == 1'b1) begin
//////////////
//////////////        // Write to output_port_k at port address 01 hex
//////////////        if (port_id[0] == 1'b1) begin
//////////////          output_port_k <= out_port;
//////////////        end
//////////////
//////////////        // Write to output_port_c at port address 02 hex
//////////////        if (port_id[1] == 1'b1) begin
//////////////          output_port_c <= out_port;
//////////////        end
//////////////
//////////////      end
//////////////  end
////////////////////////  always @ (posedge clk)
////////////////////////  begin
////////////////////////      if (interrupt_ack == 1'b1) begin
////////////////////////         interrupt = 1'b0;
////////////////////////      end
////////////////////////      else if (int_request == 1'b1) begin
////////////////////////          interrupt = 1'b1;
////////////////////////      end
////////////////////////      else begin
////////////////////////          interrupt = interrupt;
////////////////////////      end
////////////////////////  end
endmodule
