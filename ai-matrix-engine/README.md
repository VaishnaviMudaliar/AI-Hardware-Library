
# AI Matrix Engine

> A parameterizable, AXI4-Stream systolic-array-based matrix multiplication accelerator for AI inference workloads.

## Overview

AI Matrix Engine is an open-source hardware project featuring a scalable, parameterizable matrix multiplication accelerator using a systolic array architecture. Built with pure **Verilog-2001** compatibility, the design handles **INT8** activation/weight streams, internal **INT32** accumulation, dynamic right-shift scaling, and **INT16/INT8** saturating quantization.

The accelerator is fully verified with self-checking testbenches and backpressure simulation in **Icarus Verilog**, serving as a core compute block within the **AI-Hardware-Library**.

---

## Current Status

✅ **Functional Verification Complete**
- AXI4-Stream protocol handshaking and backpressure handling ($T_{VALID} / T_{READY}$).
- Signed fixed-point arithmetic verified ($100\%$ test vector parity across short and extended stream packets).
- Automated self-checking testbench passing with GTKWave trace visualization.

---

## Features & Specifications

- **Pure Verilog-2001 Compatibility:** Synthesizable without SystemVerilog constructs.
- **AXI4-Stream Wrapped Interface:** Handshake-driven execution handling non-blocking stalls and streaming bursts.
- **Precision & Scaling:**
  - **Inputs:** Signed 8-bit integers (`INT8`).
  - **Accumulation:** Signed 32-bit registers (`INT32`) to prevent overflow.
  - **Post-Processing:** Dynamic arithmetic right-shift (`shift_amount`) and 2's complement saturating clipping to configurable bit-widths (`OUT_WIDTH = 8/16`).
- **Verifiable Hardware:** Includes an automated self-checking testbench and VCD waveform output (`waveform.vcd`).

---

## Architecture & Dataflow


```

Activation Stream (A)            Weight Stream (B)
[M * IN_WIDTH] flat bus        [N * IN_WIDTH] flat bus
          │                                │
          ▼                                ▼
┌─────────────────────────────────────────────────────────┐
│         AXI4-Stream Wrapper Interface (Handshakes)      │
└───────────────────────────┬─────────────────────────────┘
                            │ (mac_enable, clr_acc)
                            ▼
┌─────────────────────────────────────────────────────────┐
│            Systolic Matrix Multiplier Array             │
│                                                         │
│   ┌──────────────┐                  ┌──────────────┐    │
│   │  PE [0,0]    │ ──── Row 0 ────> │  PE [0,N-1]  │    │
│   └──────┬───────┘                  └──────┬───────┘    │
│          │ Col 0                           │ Col N-1    │
│          ▼                                 ▼            │
│   ┌──────────────┐                  ┌──────────────┐    │
│   │ PE [M-1,0]   │ ──── Row M-1 ──> │ PE [M-1,N-1] │    │
│   └──────┬───────┘                  └──────┬───────┘    │
└──────────┼─────────────────────────────────┼────────────┘
           │ [32-bit INT32 Acc]              │ [32-bit INT32 Acc]
           ▼                                 ▼
┌─────────────────────────────────────────────────────────┐
│     Post-Processor Array (Arithmetic Shift + Clamp)     │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
                      Master Stream (C)
                [M * N * OUT_WIDTH] flat bus

```

---

## Module Breakdown

```text
rtl/
├── axi_systolic_matrix_multiplier.v   # AXI4-Stream interface & pipeline control
└── systolic_matrix_multiplier.v       # Core grid generator, PE, and Post-Processor
    ├── pe                             # Signed INT8 multiplier + INT32 accumulator
    ├── post_processor                 # Dynamic right-shift & saturating clipping
    └── systolic_matrix_multiplier     # Parameterized M x N array layout

```

---

## Parameters Specification

| Parameter | Default Value | Description |
| --- | --- | --- |
| `M` | `4` | Rows in activation matrix / hardware array height |
| `N` | `4` | Columns in weight matrix / hardware array width |
| `IN_WIDTH` | `8` | Bit-width of input activations & weights (`INT8`) |
| `ACC_WIDTH` | `32` | Bit-width of internal processing element accumulators (`INT32`) |
| `OUT_WIDTH` | `16` | Bit-width of post-processed master output stream (`INT16` or `INT8`) |

---

## Simulation & Verification

### Prerequisites

Install **Icarus Verilog** and **GTKWave**:

```bash
sudo apt-get update
sudo apt-get install iverilog gtkwave

```

### Running Test Suite

Run the self-checking testbench to verify streaming execution and signed quantization under simulated backpressure:

```bash
iverilog -o sim_axis_out verification/tb_axi_systolic_matrix_multiplier.v rtl/axi_systolic_matrix_multiplier.v rtl/systolic_matrix_multiplier.v && vvp sim_axis_out

```

### Inspecting Waveforms

View signal handshakes, clock cycles, and register dumps in GTKWave:

```bash
gtkwave waveform.vcd &

```

---

## Development Roadmap

### Phase 1: Specifications & Interfaces

* [x] Architecture Specification & Block Diagram
* [x] Parameterized Interface Definition

### Phase 2: RTL & Arithmetic Implementation

* [x] Signed Processing Element Design (`pe`)
* [x] Output Quantization & Saturation Logic (`post_processor`)
* [x] Pure Verilog-2001 $M \times N$ Array Integration

### Phase 3: AXI4-Stream Integration & Verification

* [x] AXI4-Stream Protocol Wrapper (`s_axis_a`, `s_axis_b`, `m_axis_c`)
* [x] Handshake Backpressure & Stall Resolution
* [x] Automated Self-Checking Verification Testbench
* [x] VCD Trace Output Setup (`waveform.vcd`)

### Phase 4: Synthesis & Physical Design (Next Steps)

* [ ] Logic Synthesis in Xilinx Vivado / Cadence Genus
* [ ] Static Timing Analysis (STA) & Slack Optimization
* [ ] Area & Power Evaluation

---

## License

This project is released under the [MIT License](https://www.google.com/search?q=LICENSE).

