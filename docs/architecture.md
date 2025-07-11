# Lycan 2 Requirements and Architecture

I don't think anything was fundamentally wrong with Lycan 1's architecture, we just didn't know the
full set of requirements to get higher flexibility and performance

## TODOs
- Determine performance goals by determining peripheral sets that should be able to function with no
  buffer overruns
- Determine how RTL dependecies should be managed in an automated and tool-agnostic way. Are
  filelists the answer?

## Project Core Goals
- Maximize throughput for the FT601
- Create a platform that can be easily reconfigured and expanded
  - Simplify the creation of new peripherals by minimizing boilerplate and creating reusable modules
    that implement common functionality
  - Allow Lycan's peripheral set to be configured declaratively with Python, JSON, etc.
  - Possibly reconfigure switching fabric connecting pins to peripherals
- Thoroughly verify components using functional and formal tooling
- Partial reconfiguration of peripherals
- Enable peripherals to be used with standard serial software (Linux)

### Sample Lycan Configuration
```
peripherals: [
    { type: "uart" }
]
```

## Device Architecture

## Block Requirements


### Peripherals

#### Supported Protocols
Tier 1: Required for the initial prototype:
- UART
    - 1 in (RX), 1 out (TX)
    - Baud rate, stop bits, parity
- SPI master
    - 1 in (MISO), 3 out (CLK, MOSI, CS)
    - Clock rate, polarity, setup/sample edges?
- SPI slave
    - 3 in (CLK, MOSI, CS), 1 out (MISO)
    - polarity, setup/sample edges?
- I2C master
    - 1 out (SCL), 1 bidir (SDA)
    - clock rate
- I2C slave
    - 1 in (SCL), 1 bidir (SDA)
- GPIO/Logic Analyzer
    - X I/O
Tier 2: Nice to have
- JTAG
    - 1 in (TDO), 4 out (TMS, TCK, TDI, RST)
- SWD
    - 2 out (SWCLK, RST), 1 bidir (SWDIO)
    - Could implement as a [CMSIS-DAP](https://arm-software.github.io/CMSIS-DAP/latest/group__DAP__Commands__gr.html) compliant device
Tier 3: Look into for future
- Generic parallel bus/memory interface
- I3C
- Onewire
    - 1 bidir
- CAN bus

#### Shared IPs
- Width conversion
    - Wide -> narrow and narrow -> wide
    - Optionally separate a header
- Memory-mapped config registers
- FIFOs (4K in the native width of the peripheral)
- Clock division & CDC?
- Timeout counter

#### Wrapper Functionality
Goal: The peripheral should not have to know the Lycan protocol. It only sees RX and TX data.
- Handles packing/unpacking data with a FIFO interface, optionally separating header
- Intercepts packets addressed to CSRs, handles write/read operations
- Local buffers to prevent data loss with bursty transaction patterns
    - Count is given to arbiter to help it make decisions
- Reconfiguration management - implemented as CSR write to WHOAMI

When the wrapper wants to send data back to the host PC, it pushes a header fo its data to the
header FIFO, and asserts vld. When it is granted control of the bus with a rdy, it first writes the
top header to the bus, then all the data associated with the header. The last data of the
transaction must have rlast asserted. It is ok for RX data to get split between USB transfers.

Each peripheral gets its own wrapper file custom generated. The wrapper has no verilog parameters,
it is entirely configured through Python prepro. When the python file is changed, it overwrites the
module declaration/ports but leaves the architecture implementation untouched.

Sample peripheral wrapper configuration for auto-generating wrapper and CSR interface SW:
```
data_width_in: 8
data_width_out: 8

pins: [
    {name: "tx", width: 1, dir: "out"},
    {name: "rx", width: 1, dir: "in"},
]

// By default, a periph reconfiguration reg, a busy flag, and a master enable are added.
// Modes: config (periph cannot write), status (host cannot write), interrupt (both can write)
csrs: [
    {name: "baud", width: 32, mode: "config", type: uint32_t, default: 10000},
    {name: "parity", width: 2, mode: "config", type: parity_t, default: PARITY_NONE},
    {name: "stop", width: 2, mode: "config", type: stop_bits_t, default: STOP_1},
]

default_params: {

}
```

Peripheral ports:
```
input logic clk,
input logic rst,
// Pins (auto-generated when module first created)
input logic tx,
output logic rx,
inout logic sda,
output logic sda_dir,

// FIFOs
input logic [IN_DATA_WIDTH-1:0] data_in,
input logic data_in_empty;
output logic data_in_rden;

output logic [OUT_DATA_WIDTH-1:0] data_out,
input logic data_out_full,
output logic data_out_wren,

// CSR-specific, eg. for foo_interrupt reg
input logic [FOO_R_WIDTH-1:0] foo_r,
output logic [FOO_R_WITH-1:0] foo_wdata,
output logic foo_wr

// Flags
output logic busy,

// Optional
input logic div_clk,

```

Wrapper Ports:
```
input logic clk,
input logic rst,
inout logic [PORTS_WIDTH-1:0] pins,
output logic [PORTS_WIDTH-1:0] pin_dirs,

input logic [31:0] packet_in;
output logic packet_in_full;
input logic packet_in_wren;

output logic [31:0] packet_out;
output logic [FIFO_DEPTH-1:0] packet_out_cnt;
output logic packet_out_empty;
input logic packet_out_rden;
output logic packet_out_valid;
input logic packet_out_rdy;
output packet_out_last;

```

#### Peripheral->Pin routing

UHHH

### Data Transfer

#### Protocol

Every transaction starts with a 32-bit header. Config transactions only allow one R/W per header,
while data transactions can send a large amount of data for a single header

Data:
- Periph Address: 3 bits (31:29)
- Config/~data: 1 bit (28)
- Len (up to 4K-4 bytes): 12 bits (27:16)
- Bottom 16 bits are reserved

Config:
- Periph Address: 3 bits (31:29)
- Config/~data: 1 bit (28)
- W/~R: 1 bit (27)
- CSR address: 3 bits (26:24)
- Register data: 24 bits (23:0)

I was also thinking about having RMW of regs happen on the FPGA instead of requiring a roundtrip to
the host PC, but for now I think simplicity and a single 24 bit write is better than having to pack
16 bit writes to make an atomic 32 bit write. Reading config flags should not be a performance
bottleneck.

#### FT601 Interface

For maximum performance, we want to write 4KB packets as much as possible. This means we should have
2x 1024x32bit FIFOs on the Lycan->host side, so that one can fill up while the other is being
written to the bus. We only need one 4KB host->Lycan FIFO. The current Lycan->host FIFO should be
flushed when it is full or after a timeout from the first transaction being written to the FIFO,
once the current transaction being written to the FIFO completes. For now, let's say Lycan
guarantees ~1ms max latency if the 4KB FIFO is not filled.

#### Arbitration

Complete transactions have to be sent through arbitration. The header always precedes the data, and
the length number is always accurate for data transactions. Config transactions are always one
packet long.

### RTL Development Flow

This project uses a Python-based preprocessor for more powerful parameterization and
meta-templating. The following commands will be available inside this repo for development:

#### Commands for all blocks

Each of the following commands can take a block name, or auto-detects it based on the current folder
you are in.

`lycan generate` - process RTL, place generated rtl in the RTL directory. special behavior for top?
`lycan lint` - wraps verilator --lint-only
`lycan elab` - wraps Vivado
`lycan syn` - wraps Vivado
`lycan impl` - wraps Vivado
`lycan bit` - wraps Vivado
`lycan flash` -wraps Vivado
`lycan verif` - Runs functional TB with cocotb/verilator
`lycan formal` - Runs formal verif with sby

#### Peripheral Creation

`lycan periph new [periph_name]` scaffolds a new peripheral directory structure, including the
peripheral definition Python file.

`lycan periph update [periph_name]` processes the svpy files for the given peripheral (or derived
from the current directory). It uses the peripheral definition file to completely regenerate the
peripheral wrapper file, replace the module declaration in the peripheral SV file, and create a
package file, functional TB stub, FV TB stub if none exists already.

The directory structure looks like the following for peripherals:
```
Example: UART
deps/
    uart_top.fpy
    uart.fpy
src/
    uart_config.py
    uart_pkg.svpy # Auto-generated from peripheral definition?
    uart_top.svpy # Auto-generated from peripheral definition
    uart.svpy # Partialy auto-generated from peripheral definition
```

#### Lycan Generation

The peripheral set and pinout is set by the src files for the lycan block.

`lycan top generate [configuration]` will generate all peripheral files depended on by the provided
lycan configuration (by default, just called lycan) and connect them to the pin routing and the bus
arbitration at the top level. It also updates the files referenced by Vivado.

#### Dependency Management

The `lycan` tool will automatically manage the generation of filelists containing dependencies of
RTL blocks. The dependency list for each module (if applicable) will be given in
`$BROOT/deps/$TOP.fpy`. It will then be expanded into `$BROOT/deps/$TOP.gf`.
To promote the use of packages, only SV files from the RTL folder are supported in the file lists.

All paths in the dependency list are relative to $REPO_ROOT/HDL. Optionally, a block subfolder and
file extension can be omitted to include the generated filelist for that block.

Including a .gf file causes it to be regenerated recursively. Once the dependency list has been
converted to absolute paths, the paths are deduplicated and checked to be valid. If a path does not
exist, a warning is printed.

```
# Example: UART implementation
# RTL specific to this module
periph_uart/rtl/uart.sv

# Instantiated modules: use block/module to include filelist
periph_uart/uart_tx
periph_uart/uart_rx
common/fifo
```
