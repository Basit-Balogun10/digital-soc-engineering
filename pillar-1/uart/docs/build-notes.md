# UART Build Notes

Running log of questions asked (and answered) while implementing this module, kept in my own words where it matters. Not a spec, not curriculum — just a memory aid for "wait, why did we decide that?"

---

## `mmio_register_bank.sv` — CTRL write/read

**Q: Should there be an `else` in `ctrl_write`'s `always_ff`, to avoid a latch?**
No — that framing borrows a rule from the wrong context. Missing-branch latch inference is a *combinational* logic concern (`always_comb`/`always @*`). `always_ff` is edge-triggered by construction, so it always synthesizes to a flip-flop regardless of whether every branch assigns something. No `else` just means "hold previous value on this edge," which is normal register behavior, not an inferred latch.

**Q: Should CTRL read be combinational or sequential — why is write sequential but read wants to be instant?**
Combinational read, sequential write — settled by what's live in the code (`assign rdata = ... ? ctrl_reg : 'x;`, with the sequential alternative commented out). The determinant isn't "are we touching a register," it's *who's creating new state vs. exposing existing state*. Write creates new state, so it must land in a flip-flop on a clock edge. Read doesn't create anything, it just selects what's already stored — making it sequential would add a needless cycle of latency that bus protocols like APB/AXI4-Lite don't want.

**Q: `tx_data` and `status` both need the FIFO, correct?**
Yes, and so does `rx_data`. TX_DATA write pushes onto `tx_fifo` (not a single-slot register); RX_DATA read pops from `rx_fifo`. STATUS is a mix: `TX_FIFO_EMPTY/FULL` and `RX_FIFO_EMPTY/FULL` are the FIFOs' own status outputs wired straight through; the rest of STATUS (`BREAK_DETECTED`, `NOISE_ERR`, `PARITY_ERR`, `FRAMING_ERR`, `RX_VALID`, `TX_BUSY`) comes from other blocks, not the FIFOs. `OVERRUN` is hybrid — set when a new RX byte arrives while `rx_fifo` is already full.

**Q: Verilator flags `address[31:4]` and `wdata[15:4]` as unused, `ctrl_reg[15:4]` as undriven — normal? Do unused bits become reserved automatically?**
`address[31:4]` unused is fine as-is — base-address validation is an upstream address decoder's job, this module only decodes its own local offset. `wdata[15:4]` will partially resolve once TX_DATA write lands (bits 9-15 stay genuinely unused regardless, nothing in the register map claims them). `ctrl_reg[15:4]` undriven is the real one: **no, reserved bits are not automatic.** That's a spec/documentation convention, not something RTL enforces on its own — an undriven slice of a declared output is `X` in sim and a dangling/tool-dependent net at synthesis. Needs an explicit driver to actually read as a defined `0`.

**Q: Tried `assign ctrl_reg[15:4] = '0;` right after the port list — got `%Error-BLKANDNBLK`, why?**
A continuous `assign` is a blocking-style combinational driver; `<=` in `always_ff` is nonblocking/procedural. Verilator doesn't support mixing those two styles on the same variable, even across non-overlapping bit ranges. Fix: drive it from *inside* the same `always_ff` block instead, as a nonblocking assignment, placed **unconditionally** (outside the `if (write_en...)`, not just after the `[1:0]` line inside it) — since there's no reset signal yet, an inside-the-if placement would leave those bits `X` until the first-ever CTRL write.

---

## `tx_fifo.sv` — first draft review

**Q: Does declaring `logic`/`int` inside a module (not a port) automatically make it a flip-flop?**
No. What determines it is entirely *how* the signal is assigned, not the declaration keyword. Procedural assignment (`<=`) inside a clocked block (`always_ff @(posedge clk)`) → real flip-flop, genuine persistence. Combinational assignment (`assign`, `always_comb`) → just wires/gates, zero storage, output is purely a function of current inputs.

**Q: So the declaration-line initializer (`int unsigned write_ptr = FIFO_DEPTH - 1;`) never persists across clock periods on its own?**
Correct. On its own it's a sim-only, time-0 value — not a clock-driven update. It's specifically the `write_ptr <= write_ptr + 1;` line inside `always_ff` that makes it a real, updating flip-flop; the initializer only ever matters for what the very first value looks like *in simulation*.

**Q: In `w <= w + 1`, where does the `w` on the RHS come from?**
The flip-flop's current stored output — whatever it was holding going into this edge (from the previous edge, or its reset/power-on state on the first one). This is exactly why nonblocking assignment is required in sequential logic: every RHS in an `always_ff` block evaluates off *pre-edge* values, and all assignments land simultaneously — modeling how real flip-flops in one clock domain all sample off each other's *old* values at the same instant, not off whatever another statement in the same block may have just written this edge.

**Q: Should `write_ptr` be decrementing instead of incrementing, given it starts at `FIFO_DEPTH-1` and checks `==0` for full?**
Directionally yes, *if* keeping that exact structure — but that structure is actually a different FIFO design (a single occupancy-counter: up on push, down on pop, full at `FIFO_DEPTH`, empty at 0) than the two-pointer approach from the concept doc, and it conflates two separate jobs into one variable: *where to write next* (needs to wrap `mod FIFO_DEPTH`) vs. *how full the FIFO is* (a separate count). Also surfaced a real out-of-bounds bug regardless of direction: `tx_fifo_reg[write_ptr+1]` indexes past the end of a `[FIFO_DEPTH-1:0]`-sized register. Landed on: two independent pointers (write/read), matching the concept doc — see below.

---

## Reset

**Q: Does an internal-only register (never a port) still need a reset?**
Yes — port-vs-internal is unrelated to whether something needs a defined starting value. Persistence (via `always_ff`) and defined-starting-value (via reset) are separate concerns. For *this* structure specifically: a dual-pointer FIFO has a real invariant — `write_ptr` and `read_ptr` must start in a known, mutually consistent relationship (both equal, i.e. empty) — otherwise `EMPTY`/`FULL` is comparing two independently-garbage power-on values before anything's even been pushed. Not a manufactured problem; reset is the standard way to actually address it. (FPGA toolchains can sometimes bake a declaration-line initializer into the bitstream as a real power-up value, but that doesn't port to ASIC, so an explicit reset is the right habit regardless.)

**Q: Why is `always_ff @(posedge clk or negedge rst_n)` asynchronous?**
Because the *sensitivity list* is what determines when the block executes at all. With `negedge rst_n` sitting in that list, a drop on `rst_n` triggers the block immediately, independent of the clock — could be mid-cycle. Maps to real hardware too: many flip-flop cells have a genuine dedicated async set/clear pin, separate from the clock/D-input path, that forces the output the instant it's asserted.

**Q: Is sync reset just `if (!rst_n)` inside a block with only `@(posedge clk)` listed?**
Yes. Since `rst_n` isn't in the sensitivity list, the block never runs just because `rst_n` changed — only on a clock edge. So reset only ever takes effect gated by the same clock edge as everything else, which is exactly why it's "synchronous." (Physically: sync reset is usually just a 2:1 mux on the flip-flop's D input, no special reset pin needed; async reset needs an actual dedicated pin and drags in its own reset-recovery timing concern.)

**Decision**: synchronous, active-low (`rst_n`), checked as the outermost condition in the same `always_ff` block, ahead of the push/pop logic.

---

## FIFO concept — depth, pointers, the extra bit

**Q: What is `FIFO_DEPTH`, precisely?**
A `parameter` (compile-time constant) — the count of byte-sized storage slots. Fixed per instantiation, logic written generically against it.

**Q: What are the write/read pointers, precisely, and what are they for?**
Two small counters holding an *index* into storage, not the data itself. Write pointer = slot the next push lands in (write, then increment). Read pointer = slot the next pop comes from (read, then increment). Both wrap at the end (ring buffer). What they're for: knowing where to write without clobbering unread data, where to read without re-reading stale data, and — by comparing them — whether the FIFO is empty or full.

**Q: Why do the pointers need one bit more than $\lceil\log_2(\text{FIFO\_DEPTH})\rceil$?**
Worked example, depth=8: addressing 8 slots needs exactly 3 bits ($2^3=8$). With *only* 3-bit pointers: start empty at read=write=0 (matches the actual reset value decided on below — the starting value itself is arbitrary to this argument; mod-8 wraparound returns to *whatever* value you started at after exactly 8 increments, regardless of what that value is). Push 8 bytes, write_ptr wraps 0→1→...→7→**0** again (mod-8 arithmetic) — identical to read_ptr. Empty and completely-full now produce the same comparison; 3-bit pointers can't tell "0 apart" from "one full lap (8) apart," since mod-8 makes 0 and 8 indistinguishable in 3 bits.

Fix: widen both pointers to 4 bits, but only use the bottom 3 (`ptr[2:0]`) as the actual memory address — let the full 4-bit value count to 15 before wrapping. Redo: read=0 (0000), push 8, write becomes 8 (1000). As 4-bit values, 0 ≠ 8 (distinguishable), but `8[2:0] = 0` (still addresses the right slot). Rule falls out naturally: **EMPTY** = pointers fully equal, all 4 bits. **FULL** = bottom 3 bits equal, but the extra bit differs.

**Q: Special meaning to the "multi-entry memory" framing?**
No hidden meaning — deliberately implementation-agnostic. §6.3 (referenced alongside it) is just the parameter table, not an implementation-choice section; nothing in the doc commits to flop-array vs. SRAM macro. At `FIFO_DEPTH=8` (or 16), a flip-flop array is the obvious practical choice — an SRAM primitive would be overkill — but the *concept* doesn't care which. Same object as the `logic [7:0] mem [0:FIFO_DEPTH-1]` shape, just described at the prose level instead of the RTL level.

**Q: Byte-sized slots — is a depth-16 FIFO really `[7:0][0:15]`-shaped? Is bit-per-slot ever normal instead?**
Yes to the shape: `logic [7:0] mem [0:15]` — first bracket is width-per-slot (8 bits = 1 byte), second is slot count. Bit-per-slot FIFOs exist elsewhere (bit-stuffing pipelines, internal serializer bookkeeping) but would be wrong *here* specifically — the rule is slot width should match the actual unit of data crossing that boundary. The CPU writes a whole byte to `TX_DATA` per transaction, so byte-wide slots are what matches; a bit-wide FIFO would force one push per bit, which doesn't correspond to any real transaction happening there.

**Q: Isn't UART bit-by-bit though — so is incoming FIFO data really a whole byte?**
Yes, and this is two different granularities that are easy to conflate. At the MMIO/CPU boundary: whole bytes (one `TX_DATA` write = one byte pushed). At the physical wire: one bit at a time, serially, over multiple baud periods (literally what "serial" means in UART). The FIFO lives on the byte-granular side; `tx_shift_register`/`rx_shift_register` are what actually do the bit-by-bit serialization.

**Q: Is `FULL`/`EMPTY` in all-caps a naming convention — I thought only parameters were?**
Half right. Looking at `mmio_register_bank.sv`'s own register-map comment: it's not just `parameter`s that are `ALL_CAPS_WITH_UNDERSCORES` in this project, documented STATUS/CTRL bit-field names are too (`TX_FIFO_FULL`, `BAUD_DIV`, etc.). `FULL`/`EMPTY` in prose refers to that register-map-level concept, not a mandate on RTL signal names — `tx_full` (lowercase, actual port name) is correct and doesn't conflict with anything. The two layers are allowed to differ: `tx_full` is the wire that ultimately feeds the documented `TX_FIFO_FULL` status bit.

**Q: Is this the same two-pointer pattern as LeetCode-style array problems?**
Yes — same pattern, running on a ring buffer in hardware instead of an array in software.

**Q: Should the pointers' initial state be 0, or the "front" of the queue (index 15 for depth=16)?**
Convention, not a technical requirement — but 0 is the practical default and "front=15" doesn't actually confer the advantage the queue metaphor suggests. A ring buffer has no fixed "front slot" once running — whichever slot `read_ptr` currently points to *is* the front, dynamically. The only real requirement is `write_ptr == read_ptr` at reset (whatever that shared value is), so EMPTY holds true initially. 0 wins on practical grounds: matches how everything else in the design resets, and reads far more intuitively in a waveform than needing to remember "15 means empty here."

**Q: Why not a single pointer — decrement on write, increment on read — instead of two?**
Traced through concretely (depth=16, start at 15): push A → pointer to 14 (A in some slot); push B → pointer to 13 (B in some slot); pop should return A (FIFO order) — but if pop just increments the *same* pointer back to 14, the next push lands in slot 14, which is where B (still unread) is sitting. Overwrites unread data. Root cause: write and pop happen at two genuinely different, independently-moving locations in the ring (the write frontier and the read frontier), except when the FIFO is empty or full. Collapsing them into one pointer conflates two different things and causes real corruption, not just an awkward description.

Real alternative to the extra-bit trick, though: keep both pointers separate and minimal-width (no extra bit), add a **third, separate occupancy counter** — up on push, down on pop, `FULL` at `FIFO_DEPTH`, `EMPTY` at 0. Same instinct, applied to a third signal instead of merged into the address pointers. Both designs (extra-bit-on-pointers vs. separate occupancy counter) are real and roughly equivalent in cost.

---

## Address routing / interconnect (applies to `mmio_register_bank.sv`, but conceptual)

**Q: CPU sends the full address to an "interconnect" (bus fabric — AXI is one concrete family of protocols implementing this role, not the general term itself), which routes to the peripheral whose base address matches. Then the peripheral routes to the specific component whose offset matches (e.g. the mmio bank), wiring in only the bits that component needs?**
Mostly right, one term swap: what crosses the bus is a **transaction** (address + control + data), not an "instruction" — instruction is a CPU-core/ISA concept describing what happened *inside* the core to produce the transaction. "Interconnect" is the correct general term for the routing fabric; AXI4/AXI4-Lite/APB/AHB/TileLink are concrete protocols implementing that role, not synonyms for it.

Correction on the second half: for *this* UART, there's no separate internal router module between the peripheral and the register bank. One register file owns all of CTRL/STATUS/TX_DATA/RX_DATA, so "route to whichever component's offset matches" **is** `mmio_register_bank`'s own `address[3:0] == 4'h00/...` comparisons — that if/case logic is the offset router, not a separate module. `uart_top`'s job is just handing the relevant address bits down (full 32-bit address, or a narrowed slice like `full_address[3:0]` if we take the port-narrowing lint fix). The interconnect has already confirmed "this belongs to the UART" before `uart_top` ever sees the transaction — nothing downstream re-checks the base address.

**Q: Why are CTRL/STATUS/TX_DATA/RX_DATA spaced 4 bytes apart (0x00/0x04/0x08/0x0C) instead of packed tighter?**
Direct consequence of two things this design already commits to: byte-addressing convention (addresses count individual bytes, standard across ARM/RISC-V/x86 and this design's own `[31:0]` address/data ports), and a 32-bit bus with no byte-enable/`wstrb` signals — nothing in the port list allows writing less than a full word. Every transaction grabs a whole aligned 4-byte chunk, so consecutive registers land 4 byte-addresses apart, not 1. (Low 2 bits of the address are always `00` for a valid access here — checking all of `address[3:0]` instead of just `address[3:2]` is a little redundant but not wrong.) Tighter packing would only make sense with a narrower bus or added byte-strobe logic for sub-word writes — not needed here since no register requires independent byte-level access within itself.
