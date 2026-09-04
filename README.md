## Hardware Implementation & PPA Metrics

The 8-function 4-bit ALU calculator was synthesized and implemented on the Xilinx Artix-7 FPGA (`xc7a35tcpg236-1`) using Vivado.

### Area & Resource Utilization (FPGA Footprint)
| Resource | Used | Available | Utilization % |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | 16 | 20,800 | [e.g., 0.08%] |
| **Slice Registers (FFs)** | 0 | 41,600 | 0.00% |
| **Bonded IOB (Ports)** | 28 | 106 | 26.42% |

### Performance & Timing Analysis
| Metric | Value |
| :--- | :--- |
| **Critical Path** | `x[0]` $\rightarrow$ `seg[0]` (via ALU propagation & 7-seg decode) |
| **Max Propagation Delay ($T_{\text{pd}}$)** | [e.g., 8.45 ns] |
| **Theoretical Maximum Frequency ($F_{\max}$)** | [e.g., 118.3 MHz] |
| **Timing Constraints** | Combinational / Unconstrained |

### Power Summary
| Power Component | Value |
| :--- | :--- |
| **Total On-Chip Power** | [e.g., 0.072 W] |
| **Dynamic Power** | [e.g., 0.000 W] |
| **Device Static Power** | [e.g., 0.072 W] |