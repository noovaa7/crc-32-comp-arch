// =============================================================================
// crc32_engine.v
//
// Configurable, streaming CRC-32 hardware accelerator.
//
// - Byte-wise (or multi-byte-wise) unrolled LFSR: folds in DATA_WIDTH/8 bytes
//   per clock instead of 1 bit/clock -> throughput = (DATA_WIDTH/8) bytes/cycle.
// - Parameterized polynomial / seed / reflection / final-XOR, so the same
//   datapath covers CRC-32 (Ethernet/802.3, poly 0x04C11DB7, the zlib/PNG
//   variant), CRC-32C (Castagnoli, poly 0x1EDC6F41), or any custom CRC-32.
// - Simple start/done handshake, AXI-Stream TLAST-compatible.
//
// Timing protocol
// ----------------
//   cyc N   : start=1                          -> crc_reg <= INIT_VAL, busy<=1
//   cyc N+1.: data_valid=1, data_in=word        -> crc_reg updated each cycle
//   cyc M   : data_valid=1 & done=1 (last word) -> fold in word, then finalize
//             (or) data_valid=0 & done=1        -> finalize with no new data
//   cyc M+1 : crc_valid=1 (one cycle pulse), crc_out = final CRC
//
// `start` may also be reasserted while busy to abort the current frame and
// begin a new one on the next cycle.
// =============================================================================

module crc32_engine #(
    parameter integer DATA_WIDTH = 8,             // bus width; must be a multiple of 8
    parameter [31:0]  POLY       = 32'h04C11DB7,  // CRC-32 (Ethernet/802.3) poly, normal (MSB-first) form
    parameter [31:0]  INIT_VAL   = 32'hFFFFFFFF,  // seed loaded on 'start'
    parameter [31:0]  XOR_OUT    = 32'hFFFFFFFF,  // final XOR mask
    parameter integer REFIN      = 1,             // reflect each input byte before folding in
    parameter integer REFOUT     = 1              // reflect the 32-bit result before final XOR
)(
    input  wire                    clk,
    input  wire                    rst_n,          // async active-low reset

    // Control
    input  wire                    start,          // pulse: (re)seed and begin a frame
    input  wire                    done,           // last-word / flush qualifier
    output reg                     busy,           // high for the duration of a frame
    output reg                     crc_valid,      // 1-cycle pulse: crc_out is valid
    output reg  [31:0]             crc_out,        // finalized CRC result

    // Streaming data-in interface
    input  wire                    data_valid,
    input  wire [DATA_WIDTH-1:0]   data_in,
    output wire                    ready           // engine can accept data this cycle
);

    localparam integer NBYTES = DATA_WIDTH / 8;

    // -------------------------------------------------------------------
    // Bit-reflection helpers (elaboration-time functions, reference the
    // module parameters directly)
    // -------------------------------------------------------------------
    function [7:0] reflect8;
        input [7:0] din;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1)
                reflect8[i] = din[7-i];
        end
    endfunction

    function [31:0] reflect32;
        input [31:0] din;
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1)
                reflect32[i] = din[31-i];
        end
    endfunction

    // -------------------------------------------------------------------
    // Single-byte CRC update: fold one byte into the running CRC using an
    // 8-stage unrolled MSB-first shift/XOR LFSR. REFIN bit-reverses the
    // byte first, which is the standard trick for computing the widely
    // used "reflected" CRC-32 (LSB-first bit order on the wire) with an
    // MSB-first shifting polynomial engine.
    // -------------------------------------------------------------------
    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0]  data_byte;
        reg   [31:0] c;
        reg   [7:0]  d;
        integer i;
        begin
            d = REFIN ? reflect8(data_byte) : data_byte;
            c = crc_in ^ {d, 24'b0};
            for (i = 0; i < 8; i = i + 1) begin
                if (c[31])
                    c = (c << 1) ^ POLY;
                else
                    c = c << 1;
            end
            crc32_byte = c;
        end
    endfunction

    // -------------------------------------------------------------------
    // Multi-byte fold-in: chain NBYTES byte updates combinationally so a
    // DATA_WIDTH-bit bus processes DATA_WIDTH/8 bytes per clock. Byte 0
    // (data_in[7:0]) is folded in first (little-endian byte order on the
    // bus). Widening DATA_WIDTH trades a longer combinational path
    // (~8*NBYTES XOR stages) for higher throughput -- pipeline the chain
    // if that path becomes the critical path at your target Fmax.
    // -------------------------------------------------------------------
    reg [31:0] crc_reg;
    reg [31:0] crc_chain [0:NBYTES];
    integer    bidx;

    always @* begin
        crc_chain[0] = crc_reg;
        for (bidx = 0; bidx < NBYTES; bidx = bidx + 1)
            crc_chain[bidx+1] = crc32_byte(crc_chain[bidx], data_in[bidx*8 +: 8]);
    end

    wire [31:0] crc_next = crc_chain[NBYTES];

    // -------------------------------------------------------------------
    // Control FSM
    // -------------------------------------------------------------------
    localparam IDLE = 1'b0, RUN = 1'b1;
    reg state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            crc_reg   <= INIT_VAL;
            crc_out   <= 32'h0;
            busy      <= 1'b0;
            crc_valid <= 1'b0;
        end else begin
            crc_valid <= 1'b0; // default; only pulses for 1 cycle below

            case (state)
                IDLE: begin
                    if (start) begin
                        crc_reg <= INIT_VAL;
                        busy    <= 1'b1;
                        state   <= RUN;
                    end
                end

                RUN: begin
                    if (data_valid) begin
                        crc_reg <= crc_next;
                        if (done) begin
                            crc_out   <= (REFOUT ? reflect32(crc_next) : crc_next) ^ XOR_OUT;
                            crc_valid <= 1'b1;
                            busy      <= 1'b0;
                            state     <= IDLE;
                        end
                    end else if (done) begin
                        // Flush: finalize on the currently accumulated CRC,
                        // no new data this cycle.
                        crc_out   <= (REFOUT ? reflect32(crc_reg) : crc_reg) ^ XOR_OUT;
                        crc_valid <= 1'b1;
                        busy      <= 1'b0;
                        state     <= IDLE;
                    end

                    // 'start' takes priority: abort/restart a frame at any point.
                    if (start) begin
                        crc_reg <= INIT_VAL;
                        busy    <= 1'b1;
                        state   <= RUN;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign ready = (state == RUN);

endmodule
