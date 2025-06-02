module MMC1_V
(
	// Inputs:
	input wire m2,
	input wire cpu_rw,
	input wire romsel,
	input wire cpu_A14,
	input wire cpu_A13,
	input wire cpu_D7,
	input wire cpu_D0,
	input [12:10] ppu_addr_in,

	// Outputs:
	output reg prg_wram_cs,
	output reg prg_rom_oe,
	output reg [17:14] prg_addr_out,
	output reg [16:12] ppu_addr_out,
	output reg ppu_ciram_a10
);

	reg [4:0] control;	 // $8000-9FFF
	reg [4:0] chr_bank_0;  // $A000-BFFF
	reg [4:0] chr_bank_1;  // $C000-DFFF
	reg [4:0] prg_bank;	// $E000-FFFF

	reg [3:0] shift;
	reg [1:0] bit_counter;
	reg bit_commit;
	reg reading;

	// Logic for prg_addr_out
	always @(*) begin
		if (control[3] == 1'b0) begin
			// 32KB Bank mode
			prg_addr_out = {prg_bank[3:1], cpu_A14};
		end else if (control[2] == 1'b0 && cpu_A14 == 1'b0) begin
			// 16KB Bank mode, first bank $8000-BFFF
			prg_addr_out = 4'b0000;
		end else if (control[2] == 1'b0 && cpu_A14 == 1'b1) begin
			// 16KB Bank mode, CPU access $C000-FFFF
			prg_addr_out = prg_bank[3:0];
		end else if (control[2] == 1'b1 && cpu_A14 == 1'b0) begin
			// 16KB Bank mode, last bank $C000-FFFF, CPU access $8000-BFFF
			prg_addr_out = prg_bank[3:0];
		end else begin
			// 16KB Bank mode, last bank $C000-FFFF, CPU access $C000-FFFF
			prg_addr_out = 4'b1111;
		end
	end

	// Logic for ppu_addr_out
	always @ (*) begin
		case (control[4])
			0: ppu_addr_out[16:12] = {chr_bank_0[4:1], ppu_addr_in[12]}; // 8KB bank mode
			1: if (ppu_addr_in[12] == 0) // 4KB bank mode
				ppu_addr_out[16:12] = chr_bank_0;
			else
				ppu_addr_out[16:12] = chr_bank_1;
		endcase
	end

	// PRG-ROM /OE
	always @(*) begin
		if (cpu_rw == 1'b1)
			prg_rom_oe = romsel;  // Prevent bus conflict
		else
			prg_rom_oe = 1'b1;
	end

	// WRAM /CS
	always @(*) begin
		if (prg_bank[4] == 1'b1)
			prg_wram_cs = 1'b1;  // WRAM disabled
		else if (m2 == 1'b1 && romsel == 1'b1 && cpu_A14 == 1'b1 && cpu_A13 == 1'b1)
			prg_wram_cs = 1'b0;  // CPU access $6000-$7FFF
		else
			prg_wram_cs = 1'b1;
	end

	// Mirroring
	always @ (*) begin
		case (control[1:0])
			2'b00: ppu_ciram_a10 <= 0;
			2'b01: ppu_ciram_a10 <= 1;
			2'b10: ppu_ciram_a10 <= ppu_addr_in[10]; // verical mirroring
			2'b11: ppu_ciram_a10 <= ppu_addr_in[11]; // horizontal mirroring
		endcase
	end

	// Process for register writes triggered on falling edge of m2
	always @(negedge m2) begin
		if (cpu_rw == 1'b1) begin
			reading <= 1'b1;
		end else begin
			if (reading == 1'b1 && romsel == 1'b0) begin
				reading <= 1'b0;

				if (cpu_D7 == 1'b1) begin
					bit_counter <= 2'b00;
					bit_commit <= 1'b0;
					control[3:2] <= 2'b11;
				end else if (bit_commit == 1'b1) begin
					bit_counter <= 2'b00;
					bit_commit <= 1'b0;

					case ({cpu_A14, cpu_A13})
						2'b00: control <= {cpu_D0, shift};
						2'b01: chr_bank_0 <= {cpu_D0, shift};
						2'b10: chr_bank_1 <= {cpu_D0, shift};
						2'b11: prg_bank <= {cpu_D0, shift};
					endcase
				end else begin
					case (bit_counter)
						2'b00: begin
							shift[0] <= cpu_D0;
							bit_counter <= 2'b01;
							end
						2'b01: begin
							shift[1] <= cpu_D0;
							bit_counter <= 2'b10;
							end
						2'b10: begin
							shift[2] <= cpu_D0;
							bit_counter <= 2'b11;
							end
						2'b11: begin
							shift[3] <= cpu_D0;
							bit_commit <= 1'b1;
							end
					endcase
				end
			end
		end
	end
	 
endmodule
