# Synchronous FIFO in SystemVerilog

Parameterizable synchronous FIFO (First In, First Out) buffer implemented in SystemVerilog. Uses a dedicated count register to generate `full` and `empty` flags, allowing the full memory depth to be used without wasting a storage slot.

## Project Structure

```
FIFO/
├── FIFO.sv       - FIFO module
└── tbFIFO.sv     - Self-checking testbench
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| DEPTH     | 8       | Number of entries in the FIFO |
| DWIDTH    | 16      | Data width in bits |

Both parameters are configurable at instantiation:

```systemverilog
FIFO #(.DEPTH(16), .DWIDTH(32)) my_fifo ( ... );
```

## Ports

| Port    | Direction | Width  | Description |
|---------|-----------|--------|-------------|
| clk     | input  | 1      | System clock |
| reset   | input  | 1      | Synchronous reset (active high) |
| wrEn    | input  | 1      | Write enable |
| rdEn    | input  | 1      | Read enable |
| dataIn  | input  | DWIDTH | Data written into the FIFO |
| dataOut | output | DWIDTH | Data read from the FIFO |
| full    | output | 1      | High when the FIFO cannot accept more data |
| empty   | output | 1      | High when the FIFO holds no data |

## Design

The module is split into four blocks:

**Write logic** — On a rising clock edge, if `wrEn` is asserted and the FIFO is not full, `dataIn` is stored at the location pointed to by `wptr`, and the write pointer advances.

**Read logic** — On a rising clock edge, if `rdEn` is asserted and the FIFO is not empty, the entry at `rptr` is driven onto `dataOut`, and the read pointer advances.

**Count logic** — A separate counter tracks how many entries are currently stored. It increments on a valid write, decrements on a valid read, and holds its value when both or neither occur:

```
{write_valid, read_valid}
    2'b10 → count + 1   (write only)
    2'b01 → count - 1   (read only)
    default → count     (both or neither)
```

**Flag logic** — Combinational flags derived directly from the count:

```systemverilog
full  = (count == DEPTH);
empty = (count == 0);
```

Using an explicit counter (rather than comparing pointers) removes the ambiguity between the full and empty conditions when `wptr == rptr`, so all DEPTH entries are usable.

## Verification

The testbench uses a **SystemVerilog queue as a reference model**. Every value written to the DUT is pushed onto the queue; every read pops the expected value and compares it against `dataOut`, reporting a mismatch if the ordering or data is wrong.

The test sequence:
1. Fills the FIFO to DEPTH entries and checks that `full` asserts.
2. Drains all DEPTH entries, checking each value against the reference model.
3. Verifies that `empty` asserts once drained.

### Run with Synopsys VCS

```bash
vcs -full64 -sverilog FIFO.sv tbFIFO.sv -o simv
./simv
```

### Run with Icarus Verilog

```bash
iverilog -g2012 -o sim FIFO.sv tbFIFO.sv
./sim
```

## Logic Synthesis with Synopsys Design Compiler

Synthesized with **Synopsys Design Compiler (X-2025.06-SP1)** targeting the **SAED 32nm** standard cell library (HVT, 0.75 V, 125 °C) at a 50 MHz clock target, with DEPTH = 8 and DWIDTH = 16.

```bash
dc_shell -f synth_fifo.tcl
```

### Area

| Metric | Value |
|--------|-------|
| Total cell area | 1769.86 µm² |
| Combinational area | 752.27 µm² |
| Noncombinational area | 1017.59 µm² |
| Total cells | 468 |
| Combinational cells | 314 |
| Sequential cells | 154 |
| Nets | 497 |

The 154 sequential cells hold the 8 × 16-bit memory array plus the read/write pointers and the count register.

### Timing

| Metric | Value |
|--------|-------|
| Clock target | 50 MHz (20 ns period) |
| Data arrival time | 12.54 ns |
| Data required time | 18.44 ns |
| **Slack** | **+5.90 ns (MET)** |
| Estimated max frequency | ~71 MHz |

**Critical path:** `count_reg[0]` → `count_reg[2]`, running through the counter's increment/decrement logic. The count register is the timing bottleneck, since its next-value logic depends on both the write and read enable conditions.

### Power (0.75 V, 125 °C)

| Component | Power | Share |
|-----------|-------|-------|
| Clock network | 22.69 µW | 49.7% |
| Registers | 21.15 µW | 46.4% |
| Combinational | 1.77 µW | 3.9% |
| **Total dynamic** | **23.51 µW** | — |
| **Cell leakage** | **22.10 µW** | — |
| **Total** | **45.61 µW** | — |

Power is split almost evenly between the clock network and the registers, which is expected for a memory-dominated design where most of the area is storage.

## FIFO Operation

```
Write:  dataIn → [ ][ ][ ][ ]  wptr advances
                     ↑
                    wptr

Read:   [A][B][C][ ] → dataOut  rptr advances
         ↑
        rptr

count tracks occupancy → full / empty
```

Data leaves the FIFO in the same order it entered (First In, First Out).