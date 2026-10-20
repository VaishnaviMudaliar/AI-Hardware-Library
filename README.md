# AI Hardware Library

An open-source collection of reusable, production-ready RTL IPs, digital IC design examples, and FPGA/ASIC implementations for modern AI accelerators.

---

## 🌟 Vision

This repository provides modular, synthesizable hardware building blocks for modern AI inference systems, ranging from low-level quantized arithmetic units to full Transformer inference accelerators.

---

## 🚀 IP Modules & Development Status

| Module | Sub-Components | Interface | Data Types | Status | Link |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **[AI Matrix Engine](./ai-matrix-engine)** | Systolic Array, MAC Array, Post-Processor | AXI4-Stream | INT8 / INT32 / INT16 | ✅ Complete | [Explore IP](./ai-matrix-engine) |
| **ReLU Accelerator** | Non-Linear Activation Engine | Direct / AXI | INT8 / FP16 | 🚧 In Progress | — |
| **Softmax Accelerator** | Exponentiation & Normalization | AXI4-Stream | INT8 / INT16 | 🚧 Planned | — |
| **LayerNorm Accelerator** | Mean/Variance Reduction Pipeline | AXI4-Stream | INT16 / FP16 | 🚧 Planned | — |
| **Top-K / Top-p** | Token Sampling Hardware | AXI4-Stream | INT16 | 🚧 Planned | — |

---

## 🛠️ Technology Stack

- **RTL & Design:** Pure Verilog-2001 / SystemVerilog
- **Simulation & Verification:** Icarus Verilog (`iverilog`), GTKWave, Synopsys VCS, Verdi
- **FPGA Toolchain:** Xilinx Vivado
- **ASIC Flow (Planned):** Cadence Genus (Synthesis), Cadence Innovus (P&R), Cadence Tempus (STA), Siemens Calibre (DRC/LVS)

---

## 📌 Repository Roadmap & Completed Features

### 🧮 AI Compute Units
- [x] **[Parameterized Systolic Array Engine](./ai-matrix-engine):** Pure Verilog-2001 $M \times N$ matrix multiplier grid.
- [x] **Pipelined Processing Elements (PE):** Signed $8 \times 8$-bit multiplier feeding a 32-bit accumulator (`INT32`).
- [x] **Quantization & Scaling:** Dynamic arithmetic right-shift and 2's complement saturating clipping (`INT16/INT8`).

### 🔌 Interfaces & Interconnect
- [x] **AXI4-Stream Protocol Wrapper:** Fully handshake-driven execution ($T_{VALID} / T_{READY}$) with backpressure stall handling.
- [ ] Parameterized Synchronous FIFO
- [ ] AXI4-Lite Control Registers

### 🔣 Transformer Operators
- [ ] Softmax Normalization Accelerator
- [ ] LayerNorm Engine
- [ ] Top-K / Top-p Sampling Hardware

### 🔢 Fixed & Floating-Point Arithmetic
- [x] INT8 / INT32 Signed Fixed-Point Pipeline
- [ ] FP16 / BF16 Floating-Point Multiply-Accumulate (MAC)
- [ ] Approximate Arithmetic Processing Units

### 🧪 Verification & Tooling
- [x] Self-checking Verilog testbenches with reference model comparisons.
- [x] Automated GTKWave waveform generation (`.vcd`).
- [ ] UVM/SystemVerilog randomized testbench environment.
- [ ] Functional & Code Coverage Reports.

---

## 📄 License

This repository is released under the [MIT License](LICENSE).
