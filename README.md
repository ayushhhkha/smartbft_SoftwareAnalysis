# Research in Software Analysis: SmartBFT

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure](#project-structure)
3. [Setup](#setup)
4. [Running the Model](#running-the-model)
5. [Available Configurations](#available-configurations)
6. [Changing Configurations](#changing-configurations)
7. [Generated Files](#generated-files)
8. [Terminal Output](#terminal-output)
9. [Understanding the Results](#understanding-the-results)
10. [HTML Reports](#html-reports)
11. [Reading TLC Coverage](#reading-tlc-coverage)
12. [Advanced TLC / CLI Notes](#advanced-tlc--cli-notes)

---

## Project Overview

This project models a simplified version of the SmartBFT/BFT-SMaRt normal consensus phase in TLA+.

The final model represents **multiple consensus instances**, not only one isolated consensus round. Each consensus instance follows the normal-phase structure:

```text
PROPOSE -> WRITE -> ACCEPT -> DECIDE -> DELIVER
```

The model therefore checks a simplified state machine replication flow:

```text
Consensus 1
    -> deliver decided value/batch
Consensus 2
    -> deliver decided value/batch
...
```

This is closer to the way BFT-SMaRt repeatedly orders batches of client requests. The model still abstracts away many implementation details, but it now includes the idea that consensus instances are executed and delivered in order.

The main safety goals are:

```text
No two correct replicas decide different values for the same consensus instance.
Correct replicas only deliver consensus instances in order.
Correct replicas only accept/decide values after the required quorum conditions.
```

---

## Project Structure

```text
.
├── SmartBFT.tla                 # Main TLA+ model
├── configs/                     # TLC configuration files
│   ├── debug-2replicas-f0.cfg
│   ├── bft-f1-no-faults.cfg
│   ├── bft-f1-faulty-leader.cfg
│   ├── bft-f1-faulty-nonleader.cfg
│   ├── bft-f2-faulty-leader.cfg
│   ├── bft-f2-faulty-nonleaders.cfg
│   └── bft-f2-extra-replicas-faulty-nonleaders.cfg
├── scripts/
│   └── parse_tlc_out.py         # Parses TLC output and generates HTML reports
├── outputs/                     # Generated .out files from TLC
├── graphs/                      # Generated DOT/SVG/PNG state graphs
├── reports/                     # Generated HTML reports
├── .tlc-meta/                   # TLC metadata/state exploration files
├── Makefile                     # Commands for running TLC and generating artifacts
└── README.md
```

The two most important inputs are:

```text
SmartBFT.tla
configs/*.cfg
```

`SmartBFT.tla` contains the actual model. The `.cfg` files define concrete TLC scenarios, such as the number of replicas, faulty replicas, leader, values, number of consensus instances, and invariants.

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
TLA+ (Temporal Logic of Actions)
```

The Makefile workflow is recommended because it supports multiple named configurations and automatically writes outputs, graphs, and reports.

---

## Running the Model

The recommended way to run the project is through the Makefile.

You no longer need to manually pass a `.cfg` file for the normal runs. Instead, the Makefile contains predefined targets for each configuration.

### Show Available Make Commands

```bash
make help
```

This prints all predefined commands.

---

### Run TLC on a Specific Configuration

Use one of the predefined commands:

```bash
make check-tiny
make check-no-faults
make check-f1-leader
make check-f1-nonleader
make check-f2-leader
make check-f2-nonleaders
make check-f2-extra
```

Example:

```bash
make check-f2-nonleaders
```

This command:

1. Runs TLC on `SmartBFT.tla`.
2. Uses the predefined config `configs/bft-f2-faulty-nonleaders.cfg`.
3. Writes the TLC output to `outputs/`.
4. Generates an HTML report in `reports/`.
5. Prints both the normal TLC output and a custom summary table in the terminal.

Generated files:

```text
outputs/bft-f2-faulty-nonleaders.out
reports/bft-f2-faulty-nonleaders.html
```

---

### Run All Configurations

```bash
make all-configs
```

This runs all predefined check targets.

Use this when you want to regenerate all verification results for the report.

---

### Generate a State Graph

For graph generation, use the tiny/debug config. Larger configs can produce extremely large and unreadable graphs.

```bash
make graph-tiny
```

This generates the DOT graph:

```text
graphs/debug-2replicas-f0.dot
```

---

### Generate an SVG State Graph

```bash
make svg-tiny
```

Generated files:

```text
outputs/debug-2replicas-f0.out
graphs/debug-2replicas-f0.dot
graphs/debug-2replicas-f0.svg
reports/debug-2replicas-f0.html
```

SVG is recommended because it stays readable when zooming.

---

### Generate a PNG State Graph

```bash
make png-tiny
```

Generated files:

```text
outputs/debug-2replicas-f0.out
graphs/debug-2replicas-f0.dot
graphs/debug-2replicas-f0.png
reports/debug-2replicas-f0.html
```

The generated HTML report will include the graph image.

---

### Use Custom TLC Options

The Makefile uses:

```text
-workers auto
```

by default.

To change TLC options for one run:

```bash
make check-tiny TLC_BASE_OPTS="-workers 1 -coverage 1"
```

For report measurements, using one worker can make results easier to compare:

```bash
make check-f2-nonleaders TLC_BASE_OPTS="-workers 1 -coverage 1"
```

---

### Clean Generated Files

```bash
make clean
```

This removes:

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
    Replicas = {1,2,3,4,5,6,7}
    Values = {v1, v2}
    MaxConsensus = 2
    F = 2
    Faulty = {4,5}
    Leader = 1
    NoValue = NoValue

INVARIANTS
    TypeOK
    Agreement
    Validity
    Integrity
    AcceptImpliesWrite
    OrderedDelivery
```

### Important Config Fields

| Field | Meaning |
| ----- | ------- |
| `Replicas` | Replica identifiers included in the model. |
| `Values` | Abstract values/batches that may be proposed. |
| `MaxConsensus` | Number of consensus instances modeled. |
| `F` | Number of Byzantine faults tolerated. |
| `Faulty` | Replicas allowed to behave Byzantine. |
| `Leader` | Replica acting as leader. |
| `NoValue` | Symbolic value used before a replica decides. |

---

### `debug-2replicas-f0.cfg`

Make target:

```bash
make check-tiny
```

Purpose:

```text
Small debugging and visualization configuration.
```

Typical setup:

```text
Replicas = {1,2}
Values = {v1}
MaxConsensus = 2
F = 0
Faulty = {}
Leader = 1
```

Use this config to:

* inspect individual TLC states,
* generate readable state graphs,
* debug model behavior,
* understand multi-consensus delivery.

This is not a realistic BFT fault-tolerant setup. It is mainly for learning and visualization.

Graph commands:

```bash
make svg-tiny
make png-tiny
```

---

### `bft-f1-no-faults.cfg`

Make target:

```bash
make check-no-faults
```

Purpose:

```text
Baseline BFT-sized configuration with no faulty replicas.
```

Typical setup:

```text
Replicas = {1,2,3,4}
Values = {v1, v2}
MaxConsensus = 2
F = 1
Faulty = {}
Leader = 1
```

This checks normal fault-free behavior using a four-replica setup.

Expected behavior:

```text
FaultyWrite should not be explored.
FaultyAccept should not be explored.
FaultyLeaderPropose should not be explored.
No invariant violations should be found.
```

---

### `bft-f1-faulty-leader.cfg`

Make target:

```bash
make check-f1-leader
```

Purpose:

```text
BFT configuration where the leader itself is Byzantine.
```

Typical setup:

```text
Replicas = {1,2,3,4}
Values = {v1, v2}
MaxConsensus = 2
F = 1
Faulty = {1}
Leader = 1
```

This tests whether the model remains safe when the leader can propose conflicting values.

Expected behavior:

```text
FaultyLeaderPropose should be explored.
CorrectLeaderPropose should not be explored.
No agreement violation should occur.
Ordered delivery should still hold.
```

---

### `bft-f1-faulty-nonleader.cfg`

Make target:

```bash
make check-f1-nonleader
```

Purpose:

```text
BFT configuration with a correct leader and one faulty non-leader.
```

Typical setup:

```text
Replicas = {1,2,3,4}
Values = {v1, v2}
MaxConsensus = 2
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

---

### `bft-f2-faulty-leader.cfg`

Make target:

```bash
make check-f2-leader
```

Purpose:

```text
Seven-replica BFT configuration with two faulty replicas, including the leader.
```

Typical setup:

```text
Replicas = {1,2,3,4,5,6,7}
Values = {v1, v2}
MaxConsensus = 2
F = 2
Faulty = {1,2}
Leader = 1
```

This checks a larger BFT setup where the leader is Byzantine.

Since `n = 7` and `F = 2`, this matches:

```text
n >= 3F + 1
7 >= 3(2) + 1
```

---

### `bft-f2-faulty-nonleaders.cfg`

Make target:

```bash
make check-f2-nonleaders
```

Purpose:

```text
Seven-replica BFT configuration with a correct leader and two faulty non-leaders.
```

Typical setup:

```text
Replicas = {1,2,3,4,5,6,7}
Values = {v1, v2}
MaxConsensus = 2
F = 2
Faulty = {4,5}
Leader = 1
```

This is one of the main larger verification configurations.

Expected behavior:

```text
Faulty non-leader behavior should be explored.
The leader remains correct.
Agreement, quorum-related invariants, and ordered delivery should hold.
```

---

### `bft-f2-extra-replicas-faulty-nonleaders.cfg`

Make target:

```bash
make check-f2-extra
```

Purpose:

```text
Larger-than-minimum BFT configuration with extra replicas and two faulty non-leaders.
```

This config keeps `F = 2` but uses more replicas than the minimum `3F + 1`.

It is useful for checking whether the model behaves correctly when the system has extra replicas beyond the minimum fault-tolerant setup.

---

## Changing Configurations

You can still edit or create new `.cfg` files in the `configs/` folder.

### Change the Number of Consensus Instances

The final model supports multiple consensus instances through:

```cfg
MaxConsensus = 2
```

This means TLC checks two consensus instances:

```text
Consensus 1
Consensus 2
```

To check only one instance:

```cfg
MaxConsensus = 1
```

To check three instances:

```cfg
MaxConsensus = 3
```

Increasing `MaxConsensus` makes the model more realistic, but it also increases the state space significantly.

---

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

To model two faulty non-leaders:

```cfg
Faulty = {4,5}
Leader = 1
F = 2
```

---

### Change the Possible Values

The model treats values as abstract possible batches.

```cfg
Values = {v1, v2}
```

This means each consensus instance may decide one of these abstract values.

To increase the number of possible batches:

```cfg
Values = {v1, v2, v3}
```

This increases the state space.

---

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
make check-f1-nonleader
```

generates:

```text
outputs/bft-f1-faulty-nonleader.out
reports/bft-f1-faulty-nonleader.html
```

Running:

```bash
make png-tiny
```

generates:

```text
outputs/debug-2replicas-f0.out
graphs/debug-2replicas-f0.dot
graphs/debug-2replicas-f0.png
reports/debug-2replicas-f0.html
```

### Output Folder Summary

| Folder | Purpose |
| ------ | ------- |
| `outputs/` | Raw TLC `.out` files |
| `graphs/` | DOT/SVG/PNG state graphs |
| `reports/` | HTML reports generated by the parser |
| `.tlc-meta/` | TLC metadata/state exploration files |

---

## Terminal Output

When running a Makefile target such as:

```bash
make check-f1-nonleader
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

The most important line is:

```text
Model checking completed. No error has been found.
```

This means TLC did not find an invariant violation for the selected configuration.

### 2. Custom Summary Table

After TLC finishes, the parser script prints a smaller summary table. Please note that this is only enabled with the coverage option. More of this can be found in section [HTML Reports](#html-reports).

Example:

```text
TLC Summary
============================================================
Input:  outputs/bft-f1-faulty-nonleader.out
Report: reports/bft-f1-faulty-nonleader.html

Top Coverage Rows
------------------------------------------------------------
Action                              Total      Distinct
------------------------------------------------------------
Init                                         1          1
CorrectLeaderPropose                        2         32
CorrectWrite                               14       1560
FaultyWrite                                51       1644
CorrectAccept                             140       1800
FaultyAccept                              624       1812
Decide                                   1400       2400
Deliver                                   900       1200
AdvanceConsensus                            2          2
Stutter                                     0       2232
============================================================
```

The exact numbers depend on the selected config.

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

These can be found in the .out file or printed in the terminal. Example:

```text
156280865 states generated, 9331232 distinct states found, 0 states left on queue.
```
If:

```text
queue_size = 0
```

then TLC finished exploring the full reachable state space for that configuration.

### Important Coverage Numbers

| Column | Meaning |
| ------ | ------- |
| `Action` | TLA+ action or expression being measured |
| `Distinct` | Number of new distinct states produced |
| `Total` | Number of times TLC evaluated/generated states for that action |

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
OrderedDelivery
```

### TypeOK

Checks that the model state has the expected structure.

For example:

```text
instances has one record per consensus instance
proposal/write/accept messages have valid senders and values
decided values are valid
delivered sets contain valid consensus instance numbers
currentConsensus is valid
```

### Agreement

Checks that no two correct replicas decide different values for the same consensus instance.

Bad example:

```text
Consensus 1:
  Replica 1 decides v1
  Replica 2 decides v2
```

If both replicas are correct, this should never happen.

### Validity

Checks that correct replicas only decide values from the modeled value set and, depending on the model definition, values that are properly proposed.

### Integrity

Checks that a correct replica only decides under the required decision conditions.

### AcceptImpliesWrite

Checks that if a correct replica sends an ACCEPT for a value, then there was already a WRITE quorum for that value.

### OrderedDelivery

Checks that replicas deliver consensus instances in order.

Bad example:

```text
Replica 1 delivers consensus 2 before consensus 1.
```

This should never happen in a replicated state machine.

---

## How to Interpret the Verification Result

A successful run means:

```text
For the selected finite configuration, TLC did not find a behavior where the checked safety properties fail.
```

For example, with:

```text
Replicas = {1,2,3,4,5,6,7}
Values = {v1,v2}
MaxConsensus = 2
F = 2
Faulty = {4,5}
Leader = 1
```

a successful run means:

```text
The simplified multi-consensus model did not allow two correct replicas to decide different values in the same consensus instance.
Correct replicas only decided after the required quorum conditions.
Correct replicas delivered consensus instances in order.
```

However, this does not prove the full BFT-SMaRt implementation correct.

The model is a simplified abstraction. It currently focuses on the normal consensus phase and abstracts away:

```text
real client request queues
actual batching logic
network delays and message loss
leader change/synchronization
state transfer
reconfiguration
cryptographic MACs/signatures
Java implementation threads and queues
performance behavior
```

The correct interpretation is:

```text
TLC confirms that our simplified multi-consensus model satisfies the checked safety properties under the tested finite configurations.
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
````

Example:

```text
reports/bft-f1-correct-leader.html
```

The HTML report is mainly useful when TLC coverage is enabled. Coverage is what allows the report to show which actions were explored, how many states they produced, and whether important actions such as `FaultyLeaderPropose`, `CorrectWrite`, `FaultyAccept`, `Decide`, and `Deliver` were actually reached.

The Makefile runs TLC with coverage disabled by default:

```bash
TLC_BASE_OPTS ?= -workers auto #-coverage 1
```

This means that the HTML report may still be generated, but it will contain much less useful information. In that case, the raw TLC output is usually enough because the report cannot show meaningful coverage rows.

To enable coverage, uncomment the `-coverage 1` option in the Makefile (around line 39):

```bash
TLC_BASE_OPTS ?= -workers auto -coverage 1
```

This option tells TLC to print coverage information every num (1) minutes. Without the option, TLC prints no coverage information.

To generate a report without a graph:

```bash
make check-f1-correct-leader
```

To generate a report with a PNG graph:

```bash
make png-tiny
```

Use the tiny config for graph reports because larger BFT configurations may produce very large graphs.

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
Deliver
AdvanceConsensus
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

The VS Code extension normally expects a matching `.cfg` file with the same base name as the `.tla` file.

For example:

```text
SmartBFT.tla
SmartBFT.cfg
```

The Makefile workflow is recommended for this project because it supports multiple named configs and automatically writes outputs, graphs, and HTML reports.

---

## Advanced TLC / CLI Notes

The Makefile internally runs commands of this form:

```bash
java -jar tla2tools.jar -workers auto -metadir .tlc-meta -config configs/bft-f1-faulty-nonleader.cfg SmartBFT.tla
```

With coverage enabled:

```bash
java -jar tla2tools.jar -workers 1 -coverage 1 -metadir .tlc-meta -config configs/bft-f1-faulty-nonleader.cfg SmartBFT.tla
```

### Important TLC Options

| Option | Meaning |
| ------ | ------- |
| `-config file` | Tells TLC which `.cfg` file to use |
| `-coverage num` | Prints coverage information every `num` minutes |
| `-dump dot,... file` | Dumps the state graph in Graphviz DOT format |
| `-metadir dir` | Stores TLC metadata in a chosen directory |
| `-workers num/auto` | Sets the number of TLC worker threads |

More information about TLC command-line options is available here:

```text
https://lamport.azurewebsites.net/tla/current-tools.pdf
```

Section 2.3 of that document lists current TLC command-line options.

### Manual TLC Command

```bash
java -jar tla2tools.jar -workers auto -metadir .tlc-meta -config configs/bft-f2-faulty-nonleaders.cfg SmartBFT.tla
```

### Manual DOT Graph Command

```bash
java -jar tla2tools.jar -workers auto -metadir .tlc-meta -config configs/debug-2replicas-f0.cfg SmartBFT.tla -dump dot,actionlabels,colorize graphs/debug-2replicas-f0.dot
```

### Convert DOT to PNG

```bash
dot -Tpng graphs/debug-2replicas-f0.dot -o graphs/debug-2replicas-f0.png
```

### Convert DOT to SVG

```bash
dot -Tsvg graphs/debug-2replicas-f0.dot -o graphs/debug-2replicas-f0.svg
```

---

## Summary

To run the small visualization/debug config:

```bash
make check-tiny
```

To run the fault-free config:

```bash
make check-no-faults
```

To test a Byzantine leader with `F = 1`:

```bash
make check-f1-leader
```

To test a Byzantine non-leader with `F = 1`:

```bash
make check-f1-nonleader
```

To test a larger `F = 2` setup with a correct leader:

```bash
make check-f2-nonleaders
```

To generate a small visual state graph:

```bash
make png-tiny
```

To clean generated files:

```bash
make clean
```

A successful run should end with:

```text
Model checking completed. No error has been found.
```
