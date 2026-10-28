# VHDL Differential Filter Accelerator

A hardware module written in VHDL that applies a **configurable differential filter** (order 3 or order 5) to a sequence of 8-bit signed samples stored in memory. It was built for the *Prova Finale di Reti Logiche* (Digital Logic Design final project) at **Politecnico di Milano**, academic year 2024/25.

The component works as a memory-mapped coprocessor. When `START` goes high, it:

1. reads the configuration from memory: the sequence length `K` (2 bytes), the filter selector `S`, and 14 coefficients;
2. streams the `K` samples (two's complement, range −128 to +127) through a sliding window;
3. computes each filtered value, normalises it **without a divider**, and saturates it to 8 bits;
4. writes the results back after the input sequence and raises `DONE`.

## Filter

$$f'(i) = \frac{1}{n}\sum_{j=-l}^{l} C_j \, f(i+j)$$

| Filter | Taps | Default coefficients | n | Hardware approximation of 1/n |
|---|---|---|---|---|
| Order 3 | 5 | `[-1, 8, 0, -8, 1]` | 12 | 2⁻⁴ + 2⁻⁶ + 2⁻⁸ + 2⁻¹⁰ |
| Order 5 | 7 | `[1, -9, 45, 0, -45, 9, -1]` | 60 | 2⁻⁶ + 2⁻¹⁰ |

The coefficients are read from memory on every run, so the same hardware works with any coefficient set. Samples before the start or past the end of the sequence are treated as 0.

## Architecture

The design is a single entity, `project_reti_logiche`. It keeps the control logic and the datapath strictly apart, in four processes:

| Process | Role |
|---|---|
| `fsm_update_state` | state register, asynchronous reset, `prev_state` tracking |
| `fsm_state_logic` | next-state logic (purely combinational) |
| `changing_state` | per-state control strobes and `o_mem_en` / `o_mem_we` |
| `combinatory_logic` | datapath: registers, MAC, normalisation, saturation |

### FSM

The diagram leaves out the two memory-access states, to keep it readable. The memory has one cycle of read latency, so every access goes through **`ASK_MEM` → `WAIT_MEM`**. A `prev_state` register records which state asked for the data, and `WAIT_MEM` uses it to dispatch to the right `READ_*` state. This way it is always clear which read the byte on the bus belongs to.

### Datapath highlights

- **Coefficient and sample shift registers**: two 56-bit registers (7 × 8 bit). They are loaded one byte at a time and shifted left by 8 bits, so the window slides over the sequence without re-reading memory.
- **Parallel multiply-accumulate**: all 5 or 7 products are summed in **one clock cycle**.
- **Overflow-safe accumulator**: in the worst case, 7 × (−128 × −128) = 114 688, which needs 18 signed bits. The accumulator is 24 bits wide, so it cannot overflow even with adversarial coefficients.
- **Separate read and write address registers**: reads start at `ADD`, writes start at `ADD + 17 + K`. Both are incremented independently, which keeps the address logic small.
- **Division-free normalisation**: dividing by `n` is replaced by a sum of arithmetic right shifts. Shifting a negative number right rounds towards −∞, so for negative values the design adds **+1 to every single shift** (+4 for order 3, +2 for order 5). This follows the specification exactly.
- **Saturation**: results outside [−128, 127] are clamped before write-back.
- **Restartable**: after `DONE` and `START` both go low, a new run can start without a reset. `RESET` is asynchronous.

## Synthesis results

Target: Xilinx Artix-7 (`xc7a200tfbg484-1`), Vivado. Clock constraint: **20 ns (50 MHz)**, set in [`src/constraints/clock.xdc`](src/constraints/clock.xdc).

| Resource | Used | Utilisation |
|---|---|---|
| Slice LUTs | 929 | 0.69 % |
| Flip-Flops | 242 | 0.09 % |
| **Latches** | **0** | 0 % |

| Timing | Value |
|---|---|
| Setup WNS | **+4.805 ns**, 0 failing endpoints |
| Hold WHS | +0.175 ns |
| Critical path | 15.2 ns → **f<sub>max</sub> ≈ 65.8 MHz** |

## Verification

| Testbench | Entity | What it covers |
|---|---|---|
| `tb_example.vhd` | `tb_example` | Example from the specification: 24 samples, order-3 filter. Checks the `START`/`DONE`/`RESET` handshake. |
| `tb_random.vhd` | `tb_random` | 20 random samples, **random coefficients**, order-5 filter. Most outputs saturate to ±127/−128. |
| `tb_stress.vhd` | `tb_stress` | **6 consecutive scenarios** (see below). |

What `tb_stress` covers:

- **long sequences**: K = 12 000 words with both filters, to check counters and addresses over a large range;
- **arithmetic corner cases**: inputs at +127 with coefficients at −128, and inputs at −128. These drive the 24-bit accumulator to its extreme values and test the saturation logic;
- **minimum-length sequences** (K = 7), and order-3 filters whose outer coefficients are not zero;
- **restart without reset**, and **reset during a computation**.

Every testbench is self-checking: it compares the memory contents with the expected output and ends with `TEST PASSATO (…)`.

## Running the simulation

1. Create a Vivado project (2020.2 or later) and add `src/design/project_reti_logiche.vhd` as a design source.
2. Add the files in `src/testbench/` as simulation sources, and set the testbench you want to run as **top**.
3. Run a **Behavioral Simulation**. If `TEST PASSATO` is not printed, increase the simulation time (Settings → Simulation → `xsim.simulate.runtime`, for example `all`). `tb_stress` needs several ms of simulated time.

To reproduce the synthesis results, add `src/constraints/clock.xdc` as a constraints source, run **Synthesis**, then use `report_utilization` and `report_timing_summary`.

## Repository structure

```
.
├── src/
│   ├── constraints/
│   │   └── clock.xdc                  # 20 ns clock (50 MHz)
│   ├── design/
│   │   └── project_reti_logiche.vhd   # the component
│   └── testbench/
│       ├── tb_example.vhd             # example from the specification
│       ├── tb_random.vhd              # random coefficients, order 5
│       └── tb_stress.vhd              # 6 scenarios, K up to 12 000
├── docs/
│   ├── report.pdf                     # technical report (Italian)
│   └── fsm.png                        # FSM diagram
└── README.md
```

## Authors

- **Andrea Compagnoni**
- **Daniele Confalonieri**

*Prova Finale di Reti Logiche, Politecnico di Milano, A.Y. 2024/25.*
