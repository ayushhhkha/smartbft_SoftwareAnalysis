# Research in Software Analysis: SmartBFT

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure](#project-structure)
3. [Setup](#setup)
4. [Running the Model](#running-the-model)
5. [Available Configurations](#available-configurations)
6. [Generated Files](#generated-files)
7. [Terminal Output](#terminal-output)
8. [Understanding the Results](#understanding-the-results)
9. [Reading TLC Coverage](#reading-tlc-coverage)
10. [Advanced TLC / CLI Notes](#advanced-tlc--cli-notes)

---

## Project Overview

This project models a simplified version of the SmartBFT/BFT-SMaRt normal consensus phase in TLA+.

The model focuses on one consensus instance:

```text
PROPOSE -> WRITE -> ACCEPT -> DECIDE
```

This means the model checks how replicas agree on one proposed value/batch, rather than modeling the full repeated log of many batches.

The main safety goal is:

```text
No two correct replicas should decide different values.
```

---

## Project Structure

```text
.
├── SmartBFT.tla                 # Main TLA+ model
├── configs/                     # TLC configuration files
├── scripts/
│   └── parse_tlc_out.py         # Parses TLC output and generates HTML reports
├── outputs/                     # Generated .out files from TLC
├── graphs/                      # Generated DOT/SVG/PNG state graphs
├── reports/                     # Generated HTML reports
├── .tlc-meta/                   # TLC metadata/state exploration files
├── Makefile                     # Commands for running TLC and generating artifacts
└── README.md
```

The two most important TLA+ files are:

```text
SmartBFT.tla
configs/*.cfg
```

`SmartBFT.tla` contains the actual model.

The `.cfg` files define concrete model-checking scenarios, such as the number of replicas, faulty replicas, leader, values, and invariants.

---

## Setup

This project is conducted through WSL and Visual Studio Code.

### Java

Ensure that Java is installed:

```bash
sudo apt update
sudo apt install openjdk-17-jdk
```

Check the version:

```bash
java -version
```

### TLA+ Tools

The Makefile expects `tla2tools.jar` to be available in the project root:

```text
tla2tools.jar
```

### Graphviz

Graphviz is required if you want to generate state graph images.

Install it with:

```bash
sudo apt update
sudo apt install graphviz
```

Check that it works:

```bash
dot -V
```

### VS Code Extension

To run `.tla` files in Visual Studio Code, install:

```text
TLA + (Temporal Logic of Actions)
```

---

## Running the Model

The recommended way to run the project is through the Makefile.

### Show Available Make Commands

```bash
make help
```

This prints the available commands and examples.

---

### Run TLC on a Config

```bash
make check CFG=configs/SmartBFT_faulty_1_nonleader.cfg
```

This command:

1. Runs TLC on `SmartBFT.tla`.
2. Uses the selected `.cfg` file.
3. Writes the TLC output to `outputs/`.
4. Generates an HTML report in `reports/`.
5. Prints both the normal TLC output and a small custom summary table in the terminal.

Example:

```bash
make check CFG=configs/SmartBFT_faulty_1_leader.cfg
```

Generated files:

```text
outputs/SmartBFT_faulty_1_nonleader.out
reports/SmartBFT_faulty_1_nonleader.html
```

---

### Generate an SVG State Graph

```bash
make svg CFG=configs/SmartBFT_tiny.cfg
```

This command first generates the DOT graph, then converts it to SVG.

Generated files:

```text
outputs/SmartBFT_tiny.out
graphs/SmartBFT_tiny.dot
graphs/SmartBFT_tiny.svg
reports/SmartBFT_tiny.html
```

SVG is recommended for state graphs because it stays clear when zooming.

---

### Generate a PNG State Graph

```bash
make png CFG=configs/SmartBFT_tiny.cfg
```

This command first generates the DOT graph, then converts it to PNG.

Generated files:

```text
outputs/SmartBFT_tiny.out
graphs/SmartBFT_tiny.dot
graphs/SmartBFT_tiny.png
reports/SmartBFT_tiny.html
```

The generated HTML report will include the PNG image.

Use the tiny config for graph generation. Larger configs may produce very large state graphs.

---

### Clean Generated Files

```bash
make clean
```

This removes generated files and folders:

```text
outputs/
graphs/
states/
.tlc-meta/
reports/
```

---

## Available Configurations

Configuration files are stored in:

```text
configs/
```

Each `.cfg` file defines a concrete TLC model-checking setup.

A config usually contains:

```cfg
INIT Init
NEXT Next

CONSTANTS
    Replicas = {1,2,3,4}
    Values = {v1, v2}
    F = 1
    Faulty = {4}
    Leader = 1
    NoValue = NoValue

INVARIANTS
    TypeOK
    Agreement
    Validity
    Integrity
    AcceptImpliesWrite
```

### `SmartBFT_tiny.cfg`

Purpose:

```text
Small debugging and visualization configuration.
```

Typical setup:

```text
Replicas = {1,2}
Values = {v1}
F = 0
Faulty = {}
Leader = 1
```

Use this config when you want to:

* understand what states look like,
* generate small state graphs,
* debug model behavior,
* inspect transitions visually.

This is not a realistic BFT fault-tolerant setup. It is mainly for learning and visualization.

Run with:

```bash
make check CFG=configs/SmartBFT_tiny.cfg
```

Generate graph with:

```bash
make png CFG=configs/SmartBFT_tiny.cfg
```

---

### `SmartBFT_faulty_1_nonleader.cfg`

Purpose:

```text
Main BFT-style configuration with a correct leader and one faulty non-leader.
```

Typical setup:

```text
Replicas = {1,2,3,4}
Values = {v1, v2}
F = 1
Faulty = {4}
Leader = 1
```

This models the case where replica `4` may behave Byzantine, while the leader is correct.

Expected behavior:

```text
FaultyWrite and FaultyAccept should be explored.
FaultyLeaderPropose should not be explored.
No invariant violations should be found.
```

Run with:

```bash
make check CFG=configs/SmartBFT_faulty_1_nonleader.cfg
```

---

### `SmartBFT_faulty_1_leader.cfg`

Purpose:

```text
Configuration where the leader itself is Byzantine.
```

Typical setup:

```text
Replicas = {1,2,3,4}
Values = {v1, v2}
F = 1
Faulty = {1}
Leader = 1
```

This tests whether the model remains safe even when the leader can propose conflicting values.

Expected behavior:

```text
FaultyLeaderPropose should be explored.
CorrectLeaderPropose should not be explored.
No agreement violation should occur.
```

Run with:

```bash
make check CFG=configs/SmartBFT_faulty_1_leader.cfg
```

---

### `SmartBFT_no_faults.cfg`

Purpose:

```text
Baseline configuration with no faulty replicas.
```

Typical setup:

```text
Replicas = {1,2,3,4}
Values = {v1, v2}
F = 1
Faulty = {}
Leader = 1
```

This checks the normal fault-free behavior of the model.

Expected behavior:

```text
FaultyWrite should not be explored.
FaultyAccept should not be explored.
FaultyLeaderPropose should not be explored.
No invariant violations should be found.
```

Run with:

```bash
make check CFG=configs/SmartBFT_no_faults.cfg
```

---

## Modifying Configurations

You can edit or create new `.cfg` files in the `configs/` folder.

### Change the Faulty Replica

To make replica `4` faulty:

```cfg
Faulty = {4}
```

To make the leader faulty:

```cfg
Faulty = {1}
Leader = 1
```

### Change the Possible Values

The model treats values as abstract possible batches.

```cfg
Values = {v1, v2}
```

This means the leader may propose either `v1` or `v2` for the single consensus instance.

To increase the number of possible batches:

```cfg
Values = {v1, v2, v3}
```

This increases the state space.

### Change the Number of Replicas

For Byzantine fault tolerance, the model assumes:

```text
n >= 3F + 1
```

For example:

```cfg
Replicas = {1,2,3,4}
F = 1
```

or:

```cfg
Replicas = {1,2,3,4,5,6,7}
F = 2
```

If this assumption is violated, TLC will report an assumption/configuration problem.

---

## Generated Files

The Makefile generates files based on the chosen config name.

For example:

```bash
make check CFG=configs/SmartBFT_faulty_1_nonleader.cfg
```

generates:

```text
outputs/SmartBFT_faulty_1_nonleader.out
reports/SmartBFT_faulty_1_nonleader.html
```

Running:

```bash
make png CFG=configs/SmartBFT_tiny.cfg
```

generates:

```text
outputs/SmartBFT_tiny.out
graphs/SmartBFT_tiny.dot
graphs/SmartBFT_tiny.png
reports/SmartBFT_tiny.html
```

### Output Folder Summary

| Folder       | Purpose                              |
| ------------ | ------------------------------------ |
| `outputs/`   | Raw TLC `.out` files                 |
| `graphs/`    | DOT/SVG/PNG state graphs             |
| `reports/`   | HTML reports generated by the parser |
| `.tlc-meta/` | TLC metadata/state exploration files |

---

## Terminal Output

When running a Makefile target such as:

```bash
make check CFG=configs/SmartBFT_faulty_1_nonleader.cfg
```

the terminal prints two kinds of output.

### 1. Raw TLC Output

This is the normal output produced by TLC. It includes information such as:

```text
TLC2 Version ...
Running breadth-first search Model-Checking ...
Computing initial states...
Finished computing initial states...
Model checking completed. No error has been found.
```

This is essentially the same content that is written to the `.out` file in `outputs/`.

The most important line is:

```text
Model checking completed. No error has been found.
```

This means TLC did not find an invariant violation for the selected configuration.

### 2. Custom Summary Table

After TLC finishes, the parser script prints a smaller summary table.

Example:

```text
TLC Summary
============================================================
Input:  outputs/SmartBFT_faulty_1_nonleader.out
Report: reports/SmartBFT_faulty_1_nonleader.html

State Summary
------------------------------------------------------------
distinct_states      2232
total_states         11481
queue_size           0

Top Coverage Rows
------------------------------------------------------------
Location                              Distinct      Total
------------------------------------------------------------
Init                                         1          1
CorrectLeaderPropose                        2         32
CorrectWrite                               14       1560
FaultyWrite                                51       1644
CorrectAccept                             140       1800
FaultyAccept                              624       1812
Decide                                   1400       2400
Stutter                                     0       2232
============================================================
```

The summary table is meant to make the run easier to understand without opening the full HTML report every time.

---

## Understanding the Results

The most important question is:

```text
Did TLC find an invariant violation?
```

If the output says:

```text
Model checking completed. No error has been found.
```

then TLC explored the finite state space for that config and found no violation of the checked invariants.

### Important State Summary Numbers

| Metric            | Meaning                                          |
| ----------------- | ------------------------------------------------ |
| `total_states`    | Total states TLC generated, including duplicates |
| `distinct_states` | Unique reachable states                          |
| `queue_size`      | States still waiting to be explored              |

If:

```text
queue_size = 0
```

then TLC finished exploring the full reachable state space for that configuration.

### Important Coverage Numbers

| Column     | Meaning                                                        |
| ---------- | -------------------------------------------------------------- |
| `Location` | TLA+ action or expression being measured                       |
| `Distinct` | Number of new distinct states produced                         |
| `Total`    | Number of times TLC evaluated/generated states for that action |

For example:

```text
CorrectWrite     Distinct: 14     Total: 1560
```

means TLC considered many possible `CorrectWrite` steps, but only 14 produced new unique states.

This is normal because many different paths may lead to states TLC has already seen.

---

## What the Model Checks

The model checks the following invariants:

```text
TypeOK
Agreement
Validity
Integrity
AcceptImpliesWrite
```

### TypeOK

Checks that the model state has the expected structure.

For example:

```text
proposal messages have valid senders and values
write messages have valid senders and values
accept messages have valid senders and values
decided values are valid
```

### Agreement

Checks that no two correct replicas decide different values.

Bad example:

```text
Replica 1 decides v1
Replica 2 decides v2
```

If both replicas are correct, this should never happen.

### Validity

Checks that a correct replica only decides a value that was proposed by the leader.

### Integrity

Checks that a correct replica only decides after the required ACCEPT quorum exists.

### AcceptImpliesWrite

Checks that if a correct replica sends an ACCEPT for a value, then there was already a WRITE quorum for that value.

---

## How to Interpret the Verification Result

A successful run means:

```text
For the selected finite configuration, TLC did not find a behavior where the checked safety properties fail.
```

For example, with:

```text
Replicas = {1,2,3,4}
Values = {v1,v2}
F = 1
Faulty = {4}
Leader = 1
```

a successful run means:

```text
The simplified model did not allow two correct replicas to decide different values.
Correct replicas only decided proposed values.
Correct replicas only decided after the required quorum conditions.
```

However, this does not prove the full BFT-SMaRt implementation correct.

The model is a simplified abstraction. It currently focuses on one consensus instance and abstracts away:

```text
multiple consensus instances
real client request queues
actual batching logic
network delays and message loss
leader change/synchronization
state transfer
reconfiguration
cryptographic MACs/signatures
Java implementation threads and queues
```

The correct interpretation is:

```text
TLC confirms that our simplified single-instance model satisfies the checked safety properties under the tested configuration.
```

The result should not be interpreted as:

```text
The entire BFT-SMaRt system is proven correct.
```

---

## HTML Reports

The parser script generates an HTML report for each run.

Reports are written to:

```text
reports/
```

Example:

```text
reports/SmartBFT_faulty_1_nonleader.html
```

The HTML report includes:

* state summary,
* coverage table,
* raw TLC coverage lines,
* state graph image if generated with `make png` or `make svg`.

To generate a report without a graph:

```bash
make check CFG=configs/SmartBFT_faulty_1_nonleader.cfg
```

To generate a report with a PNG graph:

```bash
make png CFG=configs/SmartBFT_tiny.cfg
```

Use the tiny config for graph reports because large BFT configurations may produce very large graphs.

---

## Reading TLC Coverage

TLC coverage statistics show which parts of the model were actually explored.

For a detailed explanation of TLC coverage statistics and how to read the generated `.out` file, see:

```text
https://explain.tlapl.us/module-coverage-statistics
```

Coverage is useful for checking whether actions such as the following were actually reached:

```text
CorrectLeaderPropose
FaultyLeaderPropose
CorrectWrite
FaultyWrite
CorrectAccept
FaultyAccept
Decide
Stutter
```

If an action has zero coverage, it usually means the action was not enabled under the current configuration.

Example:

```text
FaultyLeaderPropose = 0
```

This is expected if:

```text
Leader = 1
Faulty = {4}
```

because the leader is not faulty in that configuration.

---

## Running with the VS Code Extension

The model can also be run directly from Visual Studio Code.

1. Open `SmartBFT.tla`.
2. Open the Command Palette:

```text
Ctrl + Shift + P
```

or on macOS:

```text
Cmd + Shift + P
```

3. Select:

```text
TLA+: Check model with TLC
```

4. Select a worker count and coverge print interval (mins). The makefile uses auto for the worker count and coverage of 1 min.

The VS Code extension normally uses the matching `.cfg` file with the same base name as the `.tla` file.

For example:

```text
SmartBFT.tla
SmartBFT.cfg
```

The Makefile workflow is recommended for this project because it supports multiple configs and automatically writes outputs, graphs, and HTML reports.

---

## Advanced TLC / CLI Notes

The Makefile internally runs commands of this form:

```bash
java -jar tla2tools.jar -workers auto -coverage 1 -metadir .tlc-meta -config configs/SmartBFT_tiny.cfg SmartBFT.tla
```

### Important TLC Options

| Option               | Meaning                                         |
| -------------------- | ----------------------------------------------- |
| `-config file`       | Tells TLC which `.cfg` file to use              |
| `-coverage num`      | Prints coverage information every `num` minutes |
| `-dump dot,... file` | Dumps the state graph in Graphviz DOT format    |
| `-metadir dir`       | Stores TLC metadata in a chosen directory       |
| `-workers num/auto`  | Sets the number of TLC worker threads           |

More information about TLC command-line options is available here:

```text
https://lamport.azurewebsites.net/tla/current-tools.pdf
```

Section 2.3 of that document lists current TLC command-line options.

### Manual TLC Command

A manual TLC run looks like:

```bash
java -jar tla2tools.jar -workers auto -coverage 1 -metadir .tlc-meta -config configs/SmartBFT_faulty_1_nonleader.cfg SmartBFT.tla
```

### Manual DOT Graph Command

```bash
java -jar tla2tools.jar -workers auto -coverage 1 -metadir .tlc-meta -config configs/SmartBFT_tiny.cfg SmartBFT.tla -dump dot,actionlabels,colorize graphs/SmartBFT_tiny.dot
```

### Convert DOT to PNG

```bash
dot -Tpng graphs/SmartBFT_tiny.dot -o graphs/SmartBFT_tiny.png
```

### Convert DOT to SVG

```bash
dot -Tsvg graphs/SmartBFT_tiny.dot -o graphs/SmartBFT_tiny.svg
```

---

## Summary

To run the main check:

```bash
make check CFG=configs/SmartBFT_faulty_1_nonleader.cfg
```

To test a Byzantine leader:

```bash
make check CFG=configs/SmartBFT_faulty_1_leader.cfg
```

To generate a small visual state graph:

```bash
make png CFG=configs/SmartBFT_tiny.cfg
```

To clean generated files:

```bash
make clean
```

A successful run should end with:

```text
Model checking completed. No error has been found.
```
