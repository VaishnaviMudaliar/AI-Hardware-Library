
# AI Matrix Engine Architecture & Design Specification

> Detailed architectural overview, module relationships, AXI4-Stream handshaking mechanics, and fixed-point arithmetic execution flow.

---

## 1. Top-Level Block Diagram

```text
                     =======================================
                     |     AXI4-Stream Top-Level Wrapper    |
                     =======================================
                                       │
           ┌───────────────────────────┴───────────────────────────┐
           │                                                       │
  s_axis_a_tdata [M*8-1:0]                                s_axis_b_tdata [N*8-1:0]
  s_axis_a_tvalid                                         s_axis_b_tvalid
  s_axis_a_tready (out)                                   s_axis_b_tready (out)
           │                                                       │
           ▼                                                       ▼
 ┌──────────────────┐                                    ┌──────────────────┐
 │  Activation Bus  │                                    │    Weight Bus    │
 └─────────┬────────┘                                    └─────────┬────────┘
           │                                                       │
           └───────────────────────────┬───────────────────────────┘
                                       │
                      Join Valid: s_a_tvalid && s_b_tvalid
                                       │
                                       ▼
                       =================================
                       | Systolic Matrix Multiplier Grid |
                       =================================
                                       │
                     ┌─────────────────┴─────────────────┐
                     │  M x N Processing Element (PE)    │
                     │  Grid (Signed 8x8 -> 32-bit Acc)  │
                     └─────────────────┬─────────────────┘
                                       │
                                raw_accumulators
                                       │
                                       ▼
                       =================================
                       |     Post-Processor Array      |
                       =================================
                       │  - Signed Arithmetic Shift    │
                       │  - Dynamic Bound Saturation   │
                       └───────────────┬─────────────────┘
                                       │
                                       ▼
                             m_axis_c_tdata [M*N*OUT_WIDTH-1:0]
                             m_axis_c_tvalid
                             m_axis_c_tready

```

---

## 2. Interface Specifications

### AXI4-Stream Ports

| Signal Name | Width (Bits) | Direction | Description |
| --- | --- | --- | --- |
| `clk` | 1 | Input | System clock |
| `rst_n` | 1 | Input | Active-low asynchronous reset |
| `s_axis_a_tdata` | `M * IN_WIDTH` | Input | Packed vector of signed INT8 input activations ($M$ parallel elements) |
| `s_axis_a_tvalid` | 1 | Input | Activation stream valid indicator |
| `s_axis_a_tready` | 1 | Output | Activation stream ready signal |
| `s_axis_b_tdata` | `N * IN_WIDTH` | Input | Packed vector of signed INT8 weights ($N$ parallel elements) |
| `s_axis_b_tvalid` | 1 | Input | Weight stream valid indicator |
| `s_axis_b_tready` | 1 | Output | Weight stream ready signal |
| `ctrl_shift_amount` | 8 | Input | Signed arithmetic right-shift value for output scaling |
| `ctrl_clr_acc` | 1 | Input | Accumulator reset pulse (asserted during $K=0$ transfer) |
| `m_axis_c_tdata` | `M * N * OUT_WIDTH` | Output | Quantized $M \times N$ matrix result flat bus |
| `m_axis_c_tvalid` | 1 | Output | Master output valid flag |
| `m_axis_c_tready` | 1 | Input | Downstream master stream ready flag |
| `m_axis_c_tlast` | 1 | Output | End-of-packet framing indicator |

---

## 3. Protocol & Control Mechanics

### Handshake Synchronization Logic

To ensure zero data loss during stream stalls, core execution is gated strictly on joint handshakes:

```verilog
assign join_valid      = s_axis_a_tvalid && s_axis_b_tvalid;
assign s_axis_a_tready = join_valid && (m_axis_c_tready || !m_axis_c_tvalid);
assign s_axis_b_tready = join_valid && (m_axis_c_tready || !m_axis_c_tvalid);

// Multiply-Accumulate triggers ONLY when both slaves accept data
assign mac_enable      = join_valid && s_axis_a_tready;

```

### Accumulator Control (`ctrl_clr_acc`)

* When starting a new matrix reduction ($K=0$), `ctrl_clr_acc` is driven high.
* The testbench/controller maintains `ctrl_clr_acc = 1` until the $K=0$ cycle successfully handshakes (`mac_enable == 1`).
* On the active handshake edge, PE accumulators are cleared and immediately loaded with the first product ($A_0 \cdot B_0$).

---

## 4. Arithmetic Pipeline Details

### Processing Element (`pe`)

* **Multiplication:** Signed $8 \times 8$-bit multiplication (`$signed(act_in) * $signed(wgt_in)`).
* **Accumulation:** Product sign-extends to 32 bits and adds to `acc_out`.
* **Overflow Prevention:** INT32 accumulator provides enough headroom to sum up to $2^{15}$ worst-case INT8 products without overflow.

### Post-Processor Unit (`post_processor`)

Executes quantization and rounding-shift logic for each grid cell:

1. **Arithmetic Shift:**

$$\text{shifted\_acc} = \text{acc\_in} \gg \text{shift\_amount}$$



*(Explicitly sign-extended using Verilog `$signed()` casting).*
2. **Dynamic Range Clipping:**
Saturates shifted accumulation values into target output bounds based on `OUT_WIDTH`:
* $\text{MAX\_POS} = 2^{\text{OUT\_WIDTH}-1} - 1$
* $\text{MIN\_NEG} = -2^{\text{OUT\_WIDTH}-1}$



---

## 5. Parameterization Matrix

| Module | Parameter | Allowed Values | Function |
| --- | --- | --- | --- |
| `axi_systolic_matrix_multiplier` | `M` | $\ge 1$ | Array row depth |
|  | `N` | $\ge 1$ | Array column width |
|  | `IN_WIDTH` | `8` | Input bit-width |
|  | `ACC_WIDTH` | `32` | Processing Element accumulator bit-width |
|  | `OUT_WIDTH` | `8`, `16` | Quantized output scalar bit-width |

```


