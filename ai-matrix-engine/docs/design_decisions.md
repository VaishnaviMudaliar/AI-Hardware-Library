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

## Decision 7: Why choose an Output-Stationary dataflow?

**Question**

Which systolic array dataflow should be adopted for the AI Matrix Engine?

**Answer**

The AI Matrix Engine adopts an **Output-Stationary (OS)** dataflow, where each Processing Element (PE) retains and updates its partial sum locally until the final output value is computed.

In this architecture:

- Input activations propagate horizontally across the systolic array.
- Weights propagate vertically through the array.
- Partial sums remain stationary within each PE and are accumulated locally.

This approach minimizes the movement of partial sums, simplifies accumulator management, and naturally maps the MAC operation into each Processing Element.

---

### Alternatives Considered

#### Weight-Stationary (WS)

In a Weight-Stationary architecture, weights remain fixed inside each Processing Element while activations stream through the array.

**Advantages**

- Reduces repeated weight accesses.
- Excellent for inference accelerators with static weights.
- Widely adopted in commercial AI accelerators.

**Disadvantages**

- Requires more sophisticated scheduling.
- More complex control logic for loading and reusing weights.
- Less intuitive for an educational hardware library.

---

#### Input-Stationary (IS)

In an Input-Stationary architecture, input activations remain local while weights and partial sums move through the array.

**Advantages**

- Efficient for specific convolution workloads.
- Reduces activation movement.

**Disadvantages**

- Increased movement of partial sums.
- More complicated interconnect design.
- Less suitable for the initial implementation.

---

### Why Output-Stationary?

The Output-Stationary approach was selected because it provides the best balance between simplicity, modularity, and scalability for the first version of the AI Matrix Engine.

The architecture offers several benefits:

- Simple Processing Element design.
- Local accumulation within each PE.
- Reduced partial-sum communication.
- Straightforward RTL implementation.
- Easier functional verification.
- Clean mapping to FPGA and ASIC design flows.
- Excellent educational value while remaining representative of practical AI accelerator architectures.

---

### Data Movement

```
      Matrix A
        →
PE ──► PE ──► PE ──► PE

↓      ↓      ↓      ↓

PE ──► PE ──► PE ──► PE

↓      ↓      ↓      ↓

PE ──► PE ──► PE ──► PE

↓      ↓      ↓      ↓

PE ──► PE ──► PE ──► PE

Weights move downward.
Activations move horizontally.
Partial sums remain inside each PE.
```

---

### Implications

Choosing an Output-Stationary architecture influences the design of every subsequent module in the AI Matrix Engine.

Specifically:

- The Processing Element (PE) will contain the accumulator register.
- The MAC unit remains purely combinational.
- Each PE forwards activation and weight data to neighboring PEs every clock cycle.
- Accumulated outputs are written only after all required multiply-accumulate operations have completed.

This modular organization simplifies verification and supports incremental scaling from a single PE to larger systolic arrays.

---

**Status:** Accepted

**Version:** AI Matrix Engine v1.0

