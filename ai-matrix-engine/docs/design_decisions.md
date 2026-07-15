# Design Decisions

This document captures the major architectural and implementation decisions made during the development of the AI Matrix Engine. Each decision is accompanied by the rationale, alternatives considered, and future considerations.

---

## Decision 1: Why begin with a Multiply-Accumulate (MAC) unit?

**Question**

Why is the MAC unit the first hardware block implemented instead of directly designing the complete systolic array?

**Answer**

Matrix multiplication is fundamentally composed of repeated multiply-accumulate operations. Every Processing Element (PE) within a systolic array performs a MAC operation on incoming operands before forwarding data to neighboring PEs.

By developing and validating the MAC independently, the correctness of the fundamental arithmetic operation can be verified before integrating it into more complex modules. This modular approach simplifies debugging, improves code reusability, and allows individual hardware blocks to be tested in isolation.

---

## Decision 2: Why is the MAC implemented as a combinational module?

**Question**

Why doesn't the MAC contain a clock or accumulator register?

**Answer**

The MAC module is intentionally implemented as pure combinational logic. Instead of internally storing accumulated values, it computes:

```
acc_out = acc_in + (a × b)
```

The accumulation register is placed inside the Processing Element (PE), which is responsible for state management and data movement.

Separating arithmetic computation from sequential storage provides several advantages:

- Promotes modular and reusable RTL.
- Simplifies unit testing.
- Enables easier pipelining.
- Allows different accumulator implementations without modifying the MAC.
- Clearly separates combinational and sequential logic.

---

## Decision 3: Why use parameterized data widths?

**Question**

Why are `DATA_WIDTH` and `ACC_WIDTH` defined as parameters?

**Answer**

Parameterization improves scalability and reuse. Different AI workloads require different numerical precisions, such as INT8, INT16, BF16, or custom fixed-point formats.

By exposing the data widths as configurable parameters, the same RTL can support multiple precision formats without requiring structural modifications.

Current default configuration:

- DATA_WIDTH = 16 bits
- ACC_WIDTH = 32 bits

Future versions may support configurable precision for quantized inference.

---

## Decision 4: Why use signed arithmetic?

**Question**

Why are the operands defined as signed values?

**Answer**

Many machine learning computations involve both positive and negative values, particularly after normalization, during training, or when processing intermediate activations.

Using signed arithmetic allows the MAC to correctly process these values while maintaining compatibility with fixed-point numerical representations.

---

## Decision 5: Why use synthesizable Verilog?

**Question**

Why avoid simulation-only constructs within the MAC?

**Answer**

The AI Matrix Engine is intended to target both FPGA and ASIC implementations.

Therefore, every RTL module should remain fully synthesizable so that it can progress through the complete digital IC design flow, including:

- Functional Verification
- Logic Synthesis
- Place and Route
- Static Timing Analysis
- FPGA Prototyping

Maintaining synthesizable RTL from the beginning avoids unnecessary redesign later in the project.

---

## Decision 6: Why build the architecture hierarchically?

**Question**

Why not implement the complete systolic array immediately?

**Answer**

The project follows a bottom-up development methodology.

```
MAC
 ↓
Processing Element (PE)
 ↓
2×2 Array
 ↓
4×4 Array
 ↓
AI Matrix Engine
```

Each module is verified independently before integration into the next level. This incremental approach reduces debugging complexity, promotes modularity, and mirrors professional hardware development practices.

---

**Status:** Accepted

**Last Updated:** July 2026
