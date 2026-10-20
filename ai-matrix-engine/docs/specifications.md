# AI Matrix Engine Specification Document

> Architectural, arithmetic, protocol, and verification design decisions for the Parameterized AXI4-Stream Matrix Multiplier.

---

## 1. Executive Summary

This document formalizes the design specifications and hardware implementation decisions for the **AI Matrix Engine**. The engine provides high-throughput matrix multiplication for deep learning inference workloads, featuring an **INT8 input precision pipeline**, **INT32 accumulation**, **dynamic right-shift scaling**, and **saturating quantization**. It is fully wrapped with an **AXI4-Stream interface** and adheres strictly to **pure Verilog-2001 syntax**.

---

## 2. System Architecture & Precision Specifications

### 2.1 Fixed-Point Data Representation
- **Activations ($A$) & Weights ($B$):** Signed 8-bit integers (`INT8`, range: $[-128, 127]$).
- **Internal Accumulators:** Signed 32-bit registers (`INT32`, range: $[-2^{31}, 2^{31}-1]$) to guarantee overflow-free inner-product reductions up to $K = 2^{15}$ steps.
- **Quantized Output Stream ($C$):** Parameterized signed integer representation (`OUT_WIDTH = 8` or `16`).

### 2.2 System Generics & Parameters

| Parameter | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `M` | Integer | `4` | Rows in activation matrix / Systolic grid height |
| `N` | Integer | `4` | Columns in weight matrix / Systolic grid width |
| `IN_WIDTH` | Integer | `8` | Bit-width of input operands (`INT8`) |
| `ACC_WIDTH` | Integer | `32` | Bit-width of internal PE accumulators (`INT32`) |
| `OUT_WIDTH` | Integer | `16` | Bit-width of output post-processor output elements |

---

## 3. Protocol & Control Specifications

### 3.1 AXI4-Stream Handshake Mechanics
- **Joint Slave Transfer Condition:** Stream transfers occur **only** on clock edges where both input channels present valid data simultaneously:
  $$\text{join\_valid} = \text{s\_axis\_a\_tvalid} \ \land \ \text{s\_axis\_b\_tvalid}$$
- **Backpressure Propagation:** The engine accepts incoming stream data only when downstream master buffers are ready to receive or currently idle:
  $$\text{s\_axis\_a\_tready} = \text{join\_valid} \ \land \ (\text{m\_axis\_c\_tready} \ \lor \ \neg \text{m\_axis\_c\_tvalid})$$
  $$\text{s\_axis\_b\_tready} = \text{join\_valid} \ \land \ (\text{m\_axis\_c\_tready} \ \lor \ \neg \text{m\_axis\_c\_tvalid})$$
- **MAC Activation Trigger:** Multiply-Accumulate execution is strictly gated by valid slave handshakes:
  $$\text{mac\_enable} = \text{join\_valid} \ \land \ \text{s\_axis\_a\_tready}$$

### 3.2 Accumulator Control & Reset Synchronization
- **Accumulator Clearing (`clr_acc`):** Driven during the first step ($K=0$) of a matrix reduction stream packet.
- **Handshake-Synchronized Reset:** `clr_acc` must remain asserted until a valid handshake completes (`mac_enable == 1`). This prevents accumulator race conditions when initial stream inputs experience backpressure stalls (`tready == 0`).

---

## 4. Arithmetic & Hardware Submodule Specifications

### 4.1 Processing Element (`pe`)
- **Multiplication:** Signed $8 \times 8$-bit multiplication (`$signed(act_in) * $signed(wgt_in)`).
- **Verilog-2001 Sign Extension Enforcements:** All sliced matrix elements are wrapped with explicit `$signed()` typecasting prior to multiplication and accumulator loading.

### 4.2 Post-Processing Unit (`post_processor`)
- **Signed Arithmetic Right-Shift:** Operations perform sign-extended arithmetic shifts (`>>>`). Shift control inputs are explicitly cast as signed 8-bit integers (`wire signed [7:0] signed_shift = $signed(shift_amount)`).
- **Dynamic 2's Complement Saturation Bounds:**
  Outputs are clamped based on `OUT_WIDTH` limits:
  $$\text{MAX\_POS} = 2^{\text{OUT\_WIDTH}-1} - 1$$
  $$\text{MIN\_NEG} = -2^{\text{OUT\_WIDTH}-1}$$
- **Clipping Functionality:**
  - If $\text{shifted\_acc} > \text{MAX\_POS} \implies \text{data\_out} = \text{MAX\_POS}$
  - If $\text{shifted\_acc} < \text{MIN\_NEG} \implies \text{data\_out} = \text{MIN\_NEG}$
  - Else $\implies \text{data\_out} = \text{shifted\_acc}[\text{OUT\_WIDTH}-1:0]$

---

## 5. Verification & Testbench Design Decisions

### 5.1 Verification Strategy
- **Layered Scoreboard Verification:** Automated comparison between hardware RTL outputs and a software reference model.
- **Random Backpressure Injection:** The master ready receiver randomly asserts `m_axis_c_tready` (70% readiness threshold) to simulate real-world AXI interconnect contention.
- **Waveform Inspection Setup:** Testbench generates VCD trace files (`waveform.vcd`) using `$dumpfile` and `$dumpvars(0, tb_axi_systolic_matrix_multiplier)`.

---

## 6. Language & Portability Constraints

- **Language Standard:** Pure **Verilog-2001** (`IEEE Std 1364-2001`).
- **Forbidden Constructs:** SystemVerilog extensions (`logic`, `always_ff`, interfaces, packages, un-sized array instantiations) are excluded to ensure zero-dependency cross-synthesis across vendor tools (Vivado, Genus, Yosys).
