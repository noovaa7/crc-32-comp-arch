**PROJECT REPORT**

**CRC-32 Hardware Accelerator**

Streaming CRC-32 computation engine with configurable start/done control
(Verilog RTL) **Group No.:** 17

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>S.No</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Name</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Roll no.</strong></p>
</div></th>
<th style="text-align: left;"></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>Akanksha Singh </span></td>
<td style="text-align: left;"><span>250102007</span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>Amudalapalli Vishnu
Priya</span></td>
<td style="text-align: left;"><span>250102012</span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>Anuva Gupta</span></td>
<td style="text-align: left;"><span>250102017</span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>Naba Ahmed</span></td>
<td style="text-align: left;"><span>250102061</span></td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

**Course:** EE2101 Computer Architecture   
**Branch:** ECE

**Date:** 28 September 2026 **Tools:** Vivado 2026.1, Overleaf, EDA
Playground **References:** [IEEE
Xplore](https://ieeexplore.ieee.org/document/8515877)  
[TI SimpleLink
Documentation](https://software-dl.ti.com/simplelink/esd/simplelink_msp432_sdk/3.30.00.13/docs/driverlib/msp432p4xx/html/group__crc32__api.html)  
[OakTrust
Repository](https://oaktrust.library.tamu.edu/server/api/core/bitstreams/8db3de76-f8fb-4aba-9281-8f11950f8782/content)  
**Summary of the project**

This project implements a configurable, streaming CRC-32 accelerator in
synthesizable Verilog. An unrolled LFSR datapath folds 8 bytes into the
CRC every clock cycle, a two-state FSM handles the start/done handshake,
and parameters for polynomial, seed, reflection, final XOR and bus width
allow the same RTL to serve CRC-32 and other custom variants. The design
was verified with a randomized self-checking testbench against an
independent software model and then taken through post-synthesis
functional and timing simulation, with utilization, timing and power
reported for 8-bit and 32-bit configurations.

**1. Introduction and Problem Statement**

**A cyclic redundancy check (CRC)** is a fixed-size checksum computed
over a block of data to detect accidental corruption. CRC-32 is used in
Ethernet, ZIP, PNG and storage protocols, where it must keep pace with
the line rate. Software needs many cycles per byte, so a dedicated
hardware engine is the natural choice for high-throughput systems.

**Problem statement.** Design a CRC-32 engine that supports streaming
data and configurable start/done control, written as synthesizable
Verilog and validated with a self-checking testbench before synthesis.

**Objectives.** (i) Compute CRC-32 on data arriving as a stream of
words, with the ability to pause between words; (ii) let an external
controller mark the start and end of a frame; (iii) keep the datapath
configurable across CRC-32 variants and bus widths; (iv) verify
correctness against an independently written reference model.

**2. Methodology**

**2.1 CRC background**

A CRC treats the message as a polynomial over GF(2) and takes the
remainder after division by a generator polynomial. For standard CRC-32
(IEEE 802.3 / zlib / PNG) the generator is
*x*<sup>32</sup> + *x*<sup>26</sup> + *x*<sup>23</sup> + *x*<sup>22</sup> + *x*<sup>16</sup> + *x*<sup>12</sup> + *x*<sup>11</sup> + *x*<sup>10</sup> + *x*<sup>8</sup> + *x*<sup>7</sup> + *x*<sup>5</sup> + *x*<sup>4</sup> + *x*<sup>2</sup> + *x* + 1
(0x04C11DB7). In hardware this is a 32-bit LFSR: for each input bit the
register shifts left and, if the bit shifted out is 1, is XORed with the
polynomial. The standard also specifies seed 0xFFFFFFFF, bit reflection
of every input byte and of the final result, and a final XOR with
0xFFFFFFFF. The well-known check value is
CRC-32("123456789") = 0xCBF43926, used here as a directed test.  
  
**2.2 Architecture overview**

The design is one module, crc32_engine, with three blocks: (a) a
combinational unrolled CRC datapath that folds a whole input word into
the running CRC in one clock; (b) a 32-bit CRC register with a
finalization stage (output reflection and XOR mask); and (c) a small
control FSM that interprets start, data_valid and done (Figure 1).

<figure id="fig:placeholder">
<img src="Picture 2.png" style="width:100.0%" />
<figcaption><em>Block diagram of the CRC-32 engine</em></figcaption>
</figure>

**2.3 Interface and parameters**

The streaming interface is compatible with an AXI-Stream style source,
where done plays the role of TLAST.

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Port</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Dir</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Width</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Function</strong></p>
</div></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">clk</td>
<td style="text-align: left;">in</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">System clock; all sequential logic on the
rising edge</td>
</tr>
<tr>
<td style="text-align: left;">rst_n</td>
<td style="text-align: left;">in</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">Asynchronous, active-low reset</td>
</tr>
<tr>
<td style="text-align: left;">start</td>
<td style="text-align: left;">in</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">Pulse: load the seed and begin a frame
(also aborts a running frame)</td>
</tr>
<tr>
<td style="text-align: left;">done</td>
<td style="text-align: left;">in</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">Marks the last data word of the frame (or
a flush with no data)</td>
</tr>
<tr>
<td style="text-align: left;">data_valid</td>
<td style="text-align: left;">in</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">Qualifies data_in; state is held when low
(stream bubbles)</td>
</tr>
<tr>
<td style="text-align: left;">data_in</td>
<td style="text-align: left;">in</td>
<td style="text-align: left;"><span>DATA_ WIDTH</span></td>
<td style="text-align: left;">Input word; byte 0 (bits 7:0) is processed
first</td>
</tr>
<tr>
<td style="text-align: left;">busy</td>
<td style="text-align: left;">out</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">High while a frame is in progress</td>
</tr>
<tr>
<td style="text-align: left;">ready</td>
<td style="text-align: left;">out</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">High while in the RUN state (no
back-pressure is applied)</td>
</tr>
<tr>
<td style="text-align: left;">crc_valid</td>
<td style="text-align: left;">out</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">One-cycle pulse: crc_out holds the final
CRC</td>
</tr>
<tr>
<td style="text-align: left;">crc_out</td>
<td style="text-align: left;">out</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">Finalized CRC; held until the next frame
completes</td>
</tr>
</tbody>
</table>

*Table 1: Port list*

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Parameter</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Default</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Purpose</strong></p>
</div></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">DATA_WIDTH</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">Bus width in bits (multiple of 8);
throughput = DATA_WIDTH/8 bytes per cycle</td>
</tr>
<tr>
<td style="text-align: left;">POLY</td>
<td style="text-align: left;">0x04C11DB7</td>
<td style="text-align: left;">Generator polynomial, normal (MSB-first)
form; CRC-32C uses 0x1EDC6F41</td>
</tr>
<tr>
<td style="text-align: left;">INIT_VAL</td>
<td style="text-align: left;">0xFFFFFFFF</td>
<td style="text-align: left;">Seed loaded on start</td>
</tr>
<tr>
<td style="text-align: left;">XOR_OUT</td>
<td style="text-align: left;">0xFFFFFFFF</td>
<td style="text-align: left;">Final XOR mask applied to the result</td>
</tr>
<tr>
<td style="text-align: left;">REFIN / REFOUT</td>
<td style="text-align: left;">/ 1</td>
<td style="text-align: left;">Reflect each input byte / the final 32-bit
result</td>
</tr>
</tbody>
</table>

*Table 2: Parameters (defaults give standard CRC-32)*

**2.4 Unrolled byte-wise datapath**

Instead of one shift per clock, the eight shift/XOR steps for a byte are
unrolled inside the function crc32_byte. Because POLY is a constant,
synthesis flattens the loop into a parallel XOR network: each next-CRC
bit is the XOR of a fixed subset of current CRC bits and input bits. For
wider buses, NBYTES = DATA_WIDTH/8 copies are chained in an always @\*
block so that a 32-bit word is folded in within one clock.

> 
>
> d = REFIN ? reflect8(data_byte) : data_byte;
>
> c = crc_in ^ {d, 24'b0};
>
> for (i = 0; i \< 8; i = i + 1)
>
> if (c\[31\]) c = (c \<\< 1) ^ POLY; else c = c \<\< 1;
>
> crc_chain\[0\] = crc_reg;
>
> for (bidx = 0; bidx \< NBYTES; bidx = bidx + 1)
>
> crc_chain\[bidx+1\] = crc32_byte(crc_chain\[bidx\], data_in\[bidx\*8
> +: 8\]);

**2.5 Reflection and finalization**

The widely used "reflected" CRC-32 processes each byte LSB first. Rather
than building a second LSB-first datapath, the design reuses one
MSB-first LFSR and bit-reverses each input byte (REFIN) and the final
result (REFOUT). Reflection only permutes wires, so it doesnt need any
logic. The finalization crc_out \<= (REFOUT ? reflect32(crc) : crc) ^
XOR_OUT is registered, so crc_out and crc_valid are glitch-free.

**2.6 Optimization approach**

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Technique</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Implementation</strong></p>
</div></th>
<th style="text-align: left;"></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">Byte-wise unrolling</td>
<td style="text-align: left;">Eight LFSR steps per byte evaluated in one
cycle( 8x throughput over a bit-serial LFSR)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Multi-byte folding</td>
<td style="text-align: left;">N BYTES chained byte updates selected by
DATA_WIDTH ( 4 bytes/cycle at 32 bits)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Logic, not memory</td>
<td style="text-align: left;">Constant POLY folds into XOR trees; no
256x32 lookup table (No BRAM or DSP; small area)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Reflection as wiring</td>
<td style="text-align: left;">Bit reversal on constants at elaboration
time ( No extra LUTs or delay)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Shared next-CRC path</td>
<td style="text-align: left;">crc_next feeds both the register update
and finalization (No duplicate datapath)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Clock-enable update</td>
<td style="text-align: left;">crc_reg updates only when data_valid = 1 (
Maps to FF enable pin; no mux LUTs)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Registered outputs</td>
<td style="text-align: left;">crc_out, crc_valid, busy driven by
flip-flops ( Clean output timing)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Minimal control FSM</td>
<td style="text-align: left;">Two states, one state bit ( Negligible
control overhead)</td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

*Table 3: Design optimizations*

**Trade-off:** widening the bus lengthens the combinational path (about
8 x N BYTES serial XOR steps before flattening). If a wide configuration
limits Fmax, the chain can be pipelined at the cost of extra latency and
registers.

**2.7 Coding guidelines and tool flow**

- Fully synthesizable Verilog: posedge clk for sequential logic, always
  @\* for combinational logic.

- Active-low asynchronous reset (negedge rst_n) on the sequential block;
  state, crc_reg, crc_out, busy and crc_valid return to known values.

- A self-checking testbench with tasks and an automatic pass/fail
  summary validates the design before synthesis.

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Step</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Stage</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Details</strong></p>
</div></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Behavioral simulation</td>
<td style="text-align: left;">RTL + testbench, no synthesis</td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Synthesis</td>
<td style="text-align: left;">Utilization and timing estimates
reviewed</td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Post-synthesis functional simulation</td>
<td style="text-align: left;">Synthesized netlist, no delays; same
testbench</td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Post-synthesis timing simulation</td>
<td style="text-align: left;">Netlist with SDF back-annotated delays;
same testbench</td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Utilization, timing and power reports</td>
<td style="text-align: left;">Both DATA_WIDTH = 8 and 32, with a 10 ns
clock constraint</td>
</tr>
</tbody>
</table>

*Table 4: Design and verification flow*

**3. FSM Design**

The control logic is a two-state FSM (Figure 2). In IDLE the engine
waits for start. On start it loads INIT_VAL into the CRC register,
raises busy and enters RUN. In RUN, each cycle with data_valid = 1 folds
one word into the CRC. When done is asserted, the finalized value is
registered into crc_out, crc_valid pulses for one cycle, busy drops and
the FSM returns to IDLE. The asynchronous reset forces IDLE.

<figure id="fig:placeholder">
<img src="Picture 1.png" style="width:100.0%" />
<figcaption><em>State Diagram of the control FSM</em></figcaption>
</figure>

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>State</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Condition</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Action</strong></p>
</div></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">IDLE</td>
<td style="text-align: left;">start = 1</td>
<td style="text-align: left;">crc_reg &lt;= INIT_VAL; busy &lt;= 1; go
to RUN</td>
</tr>
<tr>
<td style="text-align: left;">IDLE</td>
<td style="text-align: left;">start = 0</td>
<td style="text-align: left;">Hold; crc_valid &lt;= 0</td>
</tr>
<tr>
<td style="text-align: left;">RUN</td>
<td style="text-align: left;">data_valid = 1, done = 0</td>
<td style="text-align: left;">crc_reg &lt;= crc_next (fold one
word)</td>
</tr>
<tr>
<td style="text-align: left;">RUN</td>
<td style="text-align: left;">data_valid = 1, done = 1</td>
<td style="text-align: left;">Fold last word; crc_out &lt;=
final(crc_next); crc_valid &lt;= 1; busy &lt;= 0; go to IDLE</td>
</tr>
<tr>
<td style="text-align: left;">RUN</td>
<td style="text-align: left;">data_valid = 0, done = 1</td>
<td style="text-align: left;">Flush: crc_out &lt;= final(crc_reg);
crc_valid &lt;= 1; busy &lt;= 0; go to IDLE</td>
</tr>
<tr>
<td style="text-align: left;">RUN</td>
<td style="text-align: left;">data_valid = 0, done = 0</td>
<td style="text-align: left;">Bubble: hold crc_reg</td>
</tr>
<tr>
<td style="text-align: left;">RUN</td>
<td style="text-align: left;">start = 1</td>
<td style="text-align: left;">Abort: crc_reg &lt;= INIT_VAL and stay in
RUN (highest priority)</td>
</tr>
</tbody>
</table>

*Table 5: State behavior*

**Timing protocol.** A frame begins with a one-cycle start pulse. From
the next cycle, words are supplied with data_valid and the last word is
marked with done. The result is registered on the same clock edge that
captures the last word, so crc_valid is high for one cycle immediately
afterwards and crc_out stays stable until the next frame completes.
Because the FSM advances only on data_valid, the source may insert any
number of idle cycles without corrupting the result.

**4. Simulation Results**

**4.1 Verification strategy**

Verification uses the self-checking testbench
tb_crc32_random_selfcheck.v plus a directed test. The testbench compares
the DUT with an independently coded software model: a table-free,
LSB-first reflected CRC-32 using polynomial 0xEDB88320, which differs
from the DUT in shift direction and bit ordering, so a shared bug is
unlikely. For each of 200 iterations it generates a random message of 1
to 64 bytes and streams it into the 8-bit DUT with random idle bubbles
(about 25% of cycles). On every fourth iteration it trims the message to
a multiple of 4 bytes and also drives the 32-bit DUT, checking it
against both the software model and the 8-bit DUT. A watchdog ends a
hung run, and the summary prints RESULT: ALL PASS or RESULT: FAILED.

**4.2 Behavioral simulation**

Figure 3 shows the directed test on the ASCII message "123456789" (bytes
0x31 to 0x39) with the 8-bit engine. After reset, a start pulse raises
busy; nine bytes are streamed with data_valid high and done asserted on
the last byte (0x39). One clock later crc_valid pulses and crc_out holds
0xCBF43926, the published CRC-32 check value.

<figure id="fig:placeholder">
<img src="WhatsApp Image 2026-09-28 at 11.10.20 PM.png"
style="width:100.0%" />
<figcaption> <em>Behavioral simulation, directed test on "123456789"
(result 0xCBF43926)</em></figcaption>
</figure>

Table 6 summarizes the randomized regression, run with *Vivado* 2026.1.
All 300 checks passed with zero failures over 200 random messages;
simulated time was about 122 µs.

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Test</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Description</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Checks</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Result</strong></p>
</div></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">Directed check value</td>
<td style="text-align: left;">"123456789" on 8-bit DUT vs
0xCBF43926</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">PASS</td>
</tr>
<tr>
<td style="text-align: left;">Random, 8-bit vs model</td>
<td style="text-align: left;">messages, 1-64 bytes, random bubbles</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">PASS</td>
</tr>
<tr>
<td style="text-align: left;">Random, 32-bit vs model</td>
<td style="text-align: left;">word-aligned messages</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">PASS</td>
</tr>
<tr>
<td style="text-align: left;">Random, 32-bit vs 8-bit</td>
<td style="text-align: left;">Same 50 messages, DUT-to-DUT</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">PASS</td>
</tr>
<tr>
<td style="text-align: left;"><strong>Total (random
regression)</strong></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><strong>300</strong></td>
<td style="text-align: left;"><strong>0 failures</strong></td>
</tr>
</tbody>
</table>

*Table 6: Behavioral verification summary*

**4.3 Post-synthesis functional simulation**

The same testbench was run on the netlist generated by *Vivado* 2026.1
for Zynq Ultra scale + ZCU 104, with no delays. This confirms that
synthesis preserved the RTL behavior, including the parameterized
unrolled chain and reset logic. Result:all checks passed and identical
CRC values to behavioural simulation

<figure id="fig:placeholder">
<img src="post synthesis functional.png" style="width:100.0%" />
<figcaption>Post-synthesis functional simulation</figcaption>
</figure>

**4.4 Post-synthesis timing simulation**

The timing simulation back-annotates delays (SDF) onto the netlist at a
clock period of 10 ns. The testbench drives inputs on the falling clock
edge and samples the result one full cycle after the last word, leaving
half a period of set-up margin. Result: outputs match benchmark
behavioral simulation values.

<figure id="fig:placeholder">
<img src="post synthesis timing.png" style="width:100.0%" />
<figcaption> <em>Post-synthesis timing simulation</em></figcaption>
</figure>

**4.5 Comparison of the three simulations**

All three levels are expected to agree on every CRC value. Behavioral
simulation checks the algorithm and protocol, functional simulation
checks that synthesis preserved it, and timing simulation adds real gate
and routing delays.

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Stage</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Checks</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Failures</strong></p>
</div></th>
<th style="text-align: left;"></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">Behavioral (RTL)</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Post-synthesis functional</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Post-synthesis timing</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

*Table 7: Simulation comparison*

**5. Utilization and Power Summary**

Synthesis was run for *Zynq Ultra Scale + ZCU104* using *Vivado* 2026.1
with a target clock period of *10 ns* . By inspection the design has 67
flip-flops (32 crc_reg + 32 crc_out + state, busy, crc_valid).

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Metric</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>DATA_WIDTH = 8</strong></p>
</div></th>
<th style="text-align: left;"></th>
<th style="text-align: left;"></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">Slice LUTs</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Slice registers (FFs)</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Block RAM / DSP</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Bonded IOs</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Worst negative slack (setup)</td>
<td style="text-align: left;">ns</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Maximum frequency (Fmax)</td>
<td style="text-align: left;">MHz</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Throughput (DATA_WIDTH x Fmax)</td>
<td style="text-align: left;">Mbps</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

*Table 8: Resource utilization and timing*

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>Power metric</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>DATA_WIDTH = 8</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Unit</strong></p>
</div></th>
<th style="text-align: left;"></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">Dynamic power</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">W</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Static (device) power</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">W</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Total on-chip power</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">W</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Junction temperature</td>
<td style="text-align: left;"></td>
<td style="text-align: left;">°C</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;">Confidence level</td>
<td style="text-align: left;">low</td>
<td style="text-align: left;">--</td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

*Table 9: Power summary*

<figure id="fig:placeholder">
<img src="power.png" style="width:100.0%" />
<figcaption><em>Power</em></figcaption>
</figure>

<figure id="fig:placeholder">
<img src="utilisation.png" style="width:100.0%" />
<figcaption><em>Utilisation</em></figcaption>
</figure>

**Discussion.** Our configuration uses 66 registers.The synthesis
results for the configuration confirm an ultra-compact logic footprint,
utilizing only 76 Slice LUTs and 66 Slice Registers (FFs). The 66
registers comprise the 32-bit CRC accumulator (FDPE), internal data
buffers, and control state logic (FDCE). Zero Block RAMs and zero DSP
blocks are consumed, as the parallel CRC checksum matrix is mapped
purely onto combinational look-up tables. With the 10ns target clock
constraint , the critical path is dominated by the multi-stage XOR
reduction tree required to process 8 parallel input bits per cycle
against the 32-bit CRC polynomial matrix. All internal
register-to-register paths closed timing cleanly with positive setup
slack.

**6. Conclusion**

We designed, verified and synthesized a configurable, streaming CRC-32
hardware accelerator. The engine folds an entire input word into the CRC
every clock cycle through an unrolled byte-wise LFSR, supports pausing
the stream with data_valid, and is controlled by a start/done handshake
driven by a two-state FSM. Parameterization of polynomial, seed, final
XOR, reflection and bus width lets the same RTL serve standard CRC-32,
CRC-32C and custom variants.

Behavioral simulation passed all 300 randomized checks against an
independent software model and reproduced the standard check value
0xCBF43926.

**Limitations and future work.** (i) With DATA_WIDTH \> 8 every word
must be full, so messages must be a multiple of the word size; a
byte-enable input would allow a partial last word. (ii) ready only
reports the RUN state and applies no back-pressure.

**7. Individual Member Contributions**

<table>
<thead>
<tr>
<th style="text-align: left;"><div class="minipage">
<p><strong>No.</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Member</strong></p>
</div></th>
<th style="text-align: left;"><div class="minipage">
<p><strong>Contribution</strong></p>
</div></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Anuva Gupta</td>
<td style="text-align: left;">RTL design of the CRC datapath:
crc32_byte, multi-byte chain, reflection functions,
parameterization.</td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Akanksha Singh</td>
<td style="text-align: left;">Control FSM, start/done handshake, timing
protocol, abort/flush behavior; FSM diagram.</td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">Naba Ahmed</td>
<td style="text-align: left;">Verification: self-checking random
testbench, software reference model, directed test, 8-bit/32-bit
cross-check.</td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td style="text-align: left;">A Vishnu Priya</td>
<td style="text-align: left;">Synthesis, post-synthesis functional and
timing simulation, utilization/power analysis, report compilation.</td>
</tr>
</tbody>
</table>
