# APB-Based SPI Controller

## 📌 Project Overview

This project implements an **APB-interfaced SPI Controller** using Verilog HDL.

The controller provides an APB slave interface through which an APB master can configure the SPI controller, transmit data, read received data, and monitor SPI status.

The design supports SPI communication with configurable:

* SPI clock polarity (**CPOL**)
* SPI clock phase (**CPHA**)
* Bit order (**LSB First / MSB First**)
* SPI master operation
* Programmable SPI baud rate
* Slave select generation
* Transmit and receive data handling
* APB error detection using `PSLVERR`

The project includes the complete RTL design, testbench, simulation waveforms, architecture documentation, lint results, and synthesis results.

---

## 🏗️ Architecture

The design consists of the following major blocks:

1. **APB Slave Interface (SPI Register Block)**
2. **SPI Baud Rate Generator**
3. **SPI Shift Register**
4. **SPI Slave Control Select**
5. **Top-Level APB SPI Controller**

The APB interface is used for configuration and data access, while the SPI interface handles serial communication with an external SPI slave.

## 🔄 Design Flow

The overall design flow used for this project is:

APB Master
    │
    ▼
APB Slave Interface
    │
    ├── SPI Configuration Registers
    ├── SPI Status Register
    └── SPI Data Register
    │
    ├──────────────► Baud Rate Generator
    │
    ├──────────────► Shift Register
    │
    └──────────────► Slave Control
                         │
                         ▼
                    SPI Interface
                  ┌───────────────┐
                  │ External SPI  │
                  │     Slave     │
                  └───────────────┘

## 📋 APB Register Map

The APB address bus is 3 bits wide.

| Address  | Register  | Access    | Description                 |
| -------- | --------- | --------- | --------------------------- |
| `3'b000` | `SPI_CR1` | R/W       | SPI control register 1      |
| `3'b001` | `SPI_CR2` | R/W       | SPI control register 2      |
| `3'b010` | `SPI_BR`  | R/W       | SPI baud rate configuration |
| `3'b011` | `SPI_SR`  | Read Only | SPI status register         |
| `3'b100` | Reserved  | —         | Reserved address            |
| `3'b101` | `SPI_DR`  | R/W       | SPI data register           |
| `3'b110` | Reserved  | —         | Reserved address            |
| `3'b111` | Reserved  | —         | Reserved address            |

## ⚙️ SPI Configuration

The controller supports the four standard SPI modes through the combination of `CPOL` and `CPHA`.

| SPI Mode | CPOL | CPHA |
| -------- | ---: | ---: |
| Mode 0   |    0 |    0 |
| Mode 1   |    0 |    1 |
| Mode 2   |    1 |    0 |
| Mode 3   |    1 |    1 |

The controller also supports:

* **MSB-first** data transmission
* **LSB-first** data transmission

The SPI clock is generated from the APB clock using programmable baud-rate divider fields.

---

## 🔌 APB Interface

The controller follows the basic APB transfer sequence:

IDLE → SETUP → ENABLE → IDLE

### Write Transfer

During a write transaction:

PSEL    = 1
PWRITE  = 1
PENABLE = 0    → SETUP phase

PENABLE = 1    → ENABLE phase

The selected register is updated with `PWDATA`.

### Read Transfer

During a read transaction:

PSEL    = 1
PWRITE  = 0
PENABLE = 0    → SETUP phase

PENABLE = 1    → ENABLE phase

The selected register value is returned through `PRDATA`.

---

## 🚨 APB Error Handling

`PSLVERR` is asserted for invalid APB accesses.

The design generates an APB error when:

* A reserved address is accessed.
* A write is attempted to the read-only `SPI_SR` register.

Valid register accesses complete with:

PSLVERR = 0

Invalid accesses generate:

PSLVERR = 1

## 🔁 SPI Data Transfer

The SPI shift register handles serial transmission and reception.

### Transmit

The transmit data is loaded from `SPI_DR` and shifted out through:

MOSI

### Receive

Serial data from the SPI slave is sampled through:

MISO

and reconstructed into an 8-bit received value.

The received data can then be read through the APB interface from:

SPI_DR

## Verification

A dedicated Verilog testbench is provided to verify the controller.

The testbench performs:

* Clock generation
* Reset generation
* APB register configuration
* APB register reads
* SPI data transmission
* MISO stimulus generation
* Received-data verification
* APB `PSLVERR` verification
* APB activity monitoring

The testbench supports different MISO stimulus patterns for MSB-first and LSB-first operation.

### Testbench File

TB/apb_spi_controller_tb.v

---

## 📊 Simulation Results

### 1. APB Register Configuration

The waveform demonstrates APB configuration of the SPI registers through APB write transactions.

### 2. SPI Data Transfer

The waveform demonstrates serial data transfer between the SPI master and slave through `MOSI`, `MISO`, `SCLK`, and `SS`.


### 3. APB Read of Received Data

After the SPI transfer, the received data is read from `SPI_DR` through the APB interface.

---

## 🛠️ Tools Used

| Tool                     | Purpose                                   |
| ------------------------ | ----------------------------------------- |
| Verilog HDL              | RTL design                                |
| ModelSim                 | RTL simulation and waveform analysis      |
| Synopsys SpyGlass        | RTL lint analysis                         |
| Synopsys Design Compiler | Logic synthesis                           |
| GitHub                   | Version control and project documentation |

---

## 📁 Project Structure

APB-Based-SPI-Controller/
│
├── RTL/
│   ├── apb_spi_controller.v
│   ├── apb_slave_interface.v
│   ├── spi_baud_gen.v
│   ├── spi_shift_register.v
│   └── spi_slave_control_select.v
│
├── TB/
│   └── apb_spi_controller_tb.v
│
├── Simulation/
│   └── Waveforms/
│       ├── 01_apb_register_configuration.png
│       ├── 02_spi_data_transfer.png
│       └── 03_apb_read_received_data.png
│
├── Documentation/
│   └── apb_spi_controller_architecture.png
│
└── Synthesis/
    ├── Reports/
    ├── Netlist/
    └── Schematic/

---

## 🎯 Key Learning Outcomes

This project provided practical experience with:

* APB protocol implementation
* SPI protocol implementation
* APB register-map design
* SPI clock generation
* CPOL/CPHA operation
* MSB-first and LSB-first data handling
* Serial-to-parallel and parallel-to-serial data conversion
* APB error handling
* Verilog RTL design
* Testbench development
* Simulation and waveform debugging
* RTL linting
* Logic synthesis
* Netlist and schematic analysis

---

## 🚀 Future Improvements

Possible extensions to the project include:

* SystemVerilog-based verification
* UVM verification environment
* Functional coverage
* Assertion-based verification
* Additional SPI slave-select support
* More extensive constrained-random testing
* Formal verification
* CDC analysis

---

## 👨‍💻 Author

**Kanaparthi Lokvardhan**

This project was developed as part of hands-on VLSI RTL design and verification practice, with emphasis on **APB, SPI, Verilog RTL design, simulation, linting, and synthesis**.
