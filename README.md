## Hardware Implementation & PPA Metrics

The 8-function 4-bit ALU target was synthesized, routed, and verified on the Xilinx Artix-7 FPGA (`xc7a35tcpg236-1`) using Vivado.

### Area & Resource Utilization
| Resource | Used | Available | Utilization % |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | 16 | 20,800 | 0.08% |
| **Slice Registers (FFs)** | 0 | 41,600 | 0.00% |
| **Bonded IOB (Ports)** | 28 | 106 | 26.42% |

### Performance & Timing Metrics
| Metric | Value |
| :--- | :--- |
| **Critical Path Delay ($T_{\text{max}}$)** | 16.822 ns |
| **Min Propagation Delay ($T_{\text{min}}$)** | 2.475 ns |
| **Maximum Equivalent Frequency ($F_{\max}$)** | 59.45 MHz |
| **Unconstrained Paths** | 10 Setup / 10 Hold |

### Key Architectural Takeaway
Because this design is 100% combinational, zero Flip-Flops (FFs) are utilized. The 16.822 ns critical path represents the combined propagation delay of the ALU logic operation cascaded into the 7-segment display decoder.