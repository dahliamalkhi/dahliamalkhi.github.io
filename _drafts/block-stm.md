# Block-STM: Accelerating Smart-Contract Processing 

[Block-STM](https://arxiv.org/pdf/2203.06871.pdf) is a recently announced technology for accelerating smart-contract execution, emanating from the 
[Diem project](https://github.com/diem)
and enhanced by 
[Aptos Labs](https://github.com/aptos-labs).
The acceleration approach interoperates with existing blockchains without requiring modification or adoption by miner/validator nodes, and can benefit a node independently through its own block processing.

## Background

An approach pioneered in the [Calvin 2012](http://cs.yale.edu/homes/thomson/publications/calvin-sigmod12.pdf) and [Bohm 2014](https://arxiv.org/pdf/1412.2324.pdf) projects in the context of distributed databases is the foundation of much of what follows. The insightful idea in those projects is to simplify concurrency management by disseminating pre-ordered batches (akin to blocks) of transactions along with pre-estimates of their read- and write- sets. 
Every database partition can then autonomously execute transactions according to the block pre-order, each transaction
waiting only for read dependencies on earlier transactions in the block. The [first DiemVM parallel executor](https://github.com/diem/diem/issues/8829) implements this approach but it relies on a static transaction analyzer to pre-estimate read/write-sets which is time consuming. 

Another work by [Dickerson et al. 2017](https://arxiv.org/abs/1702.04467)
provides a link from traditional database concurrency to smart-contract parallelism. In that work, a consensus *leader* (or *miner*) pre-computes a parallel execution serialization by
harnessing optimistic software transactional memory (STM) 
and disseminates the pre-execution scheduling guidelines to all *validator* nodes. 
A later work [OptSmart 2021](https://arxiv.org/abs/2102.04875) adds read/write-set dependency tracking during pre-execution and disseminates this information to increase parallelism. 
Those approaches remove the reliance on static transaction analysis but require a leader to pre-execute blocks.

The Block-STM parallel executor combines the pre-ordered block idea with optimistic STM to enforce the block pre-order of transactions on-the-fly, completely removing the need to pre-disseminate an execution schedule or pre-compute transaction dependencies, while guaranteeing repeatability.

## Technical Overview

Block-STM is a parallel execution engine for smart contracts, built around the principles of Software Transactional Memory. 
Transactions are grouped in blocks, each block containing a pre-ordered sequence of transactions
TX1, TX2, ..., TXn. Transactions consist of smart-contract code that reads and writes to shared memory and their
execution results in a read-set and a write-set: the read-set consists of pairs, a memory location and the transaction that wrote it; the write-set consists of pairs, a memory location and a value, that the transaction would record if it became committed.

**Block pre-order:**
A parallel execution of the block must yield the same deterministic outcome 
that preserves a block pre-order, namely, it results in exactly the same read/write sets as a sequential execution. 
If, in a sequential execution, TXk reads a value that TXj wrote, 
i.e., TXj is the highest transaction preceding TXk that writes to this particular memory location, 
we denote this by:

> TXj &rarr; TXk 

A parallel execution must guarantee that all transactions indeed read values adhering to these dependencies. 
That is, when TXk reads from memory, it must obtain the value(s) written by TXj, TXj &rarr; TXk, if a dependency exists;
or the initial value at that memory location when the block execution started, if none. 

**Correctness:**
Block-STM uses an optimistic approach, executing tranascations greedily and optimistically in parallel and then validating their read-set, 
potentially causing abort/re-execute. 
Correct optimism revolves around maintaining two principles:

* **VALIDAFTER(j, k)**: For every j,k, such that j < k, a validation of TXk is performed after TXj executes (or re-executes).
* **READLAST(k)**: Whenever TXk executes (speculatively), a read by TXk obtains the value recorded so far by the highest transaction TXj preceding it, i.e., where j < k. Higher transactions TXl, where l > k, do not intefer with TXk. 

Jointly, these two principles 
suffice to guarantee both safety and liveness no matter what scheduling policy is used, so long as pending execution and validation tasks are eventually dispatched. Safety follows because a TXk gets validated after all TXj, j &lt; k, are finalized. Liveness follows by induction. Initially transaction 1 is guaranteed to pass validation successfully and not require re-execution. After transactions TX1-TXj have successfully validated, a (re-)execution of transaction j+1 will pass validation successfully and not require re-execution.

**READLAST(k)** is achieved via a simple multi-version in-memory data structure that keeps versioned write-sets. A write by TXj is recorded with version j. 
A read by TXk obtains the value recorded by the latest invocation of TXj with the highest j &lt; k.

A special value `ABORTED` may be stored at version j when the latest invocation of TXj aborts. 
If TXk reads this value, it suspends and resumes when the value becomes set.  

**VALIDAFTER(j, k)** is implemented by a scheduler. For each j, after TXj completes a (re-)execution, the scheduler dispatched every TXk with index k > j for (re)validation. Validation re-reads the read-set of the TXk and compares against the original read-set that TXk obtained in its latest execution. If validation fails, TXk re-executes.

## Scheduling

It remains to focus on devising an efficient schedule for parallelizing execution and validations. We will construct an effective scheduling strategy gradually, starting with a correct but inefficient strawman and gradually improving it in three steps. The full scheduling strategy is 
described in under 20 lines of pseudo-code. 

 

At a first cut, consider a strawman scheduler, S-1, that uses a centralized dispatcher that coordinates work by parallel threads.

## **S-1:**


```
# Phase 1: 
dispatch all TX’s for execution in parallel ; wait for completion

# Phase 2: 
repeat {
    dispatch all all TX's for validation in parallel ; wait for completion
} until all validations pass

validation of TXj {
    re-read TXj read-set 
    if read-set differs from original read-set of the latest TXj execution 
        re-execute
}

execution of TXj {
    (re-)execute TXj
}
```

S-1 operates in two master-coordinated phases. Phase 1 executes all transactions optimistically in parallel. Phase 2 repeatedly validates all transactions optimistically in parallel, re-executing those that fail, until there are no more validation failures. 

**A running example:**
A scenario serving as a running example throughout this post is a block B consisting of ten transactions TX1-TX10. 
B has the following read/write dependencies:

<!--- TX1 writes M[0] reads M[3] -->
<!--- TX2 writes M[1] reads M[0] -->
<!--- TX3 writes M[2] reads M[1] -->
<!--- TX4 writes M[0] reads M[3] -->
<!--- TX5 writes M[1] reads M[0] -->
<!--- TX6 writes M[2] reads M[1] -->
<!--- TX7 writes M[0] reads M[3] -->
<!--- TX8 writes M[1] reads M[0] -->
<!--- TX9 writes M[2] reads M[1] -->
<!--- TX10 writes M[0] reads M[3] -->

> TX1 &rarr; TX2 &rarr; TX3        
> TX4 &rarr; TX5 &rarr; TX6        
> TX7 &rarr; TX8 &rarr; TX9 

With four threads, S-1 will possibly proceed though the following time steps:

```
Possible time steps S-1 goes through with four threads:
Phase 1:       
  1. parallel execution of TX1, TX2, TX3, TX4
  2. parallel execution of TX5, TX6, TX7, TX8
  3. parallel execution of TX9, TX10
Phase 2:       
  1. parallel validation of all transactions in which TX2, TX3, TX5, TX6 fail and re-execute
  2. continued parallel validation of all transactions in which TX8, TX9 fail and re-execute
  3. parallel validation of all transactions in which TX3, TX6, TX9 fail and re-execute
  4. parallel validation of all transactions in which all succeed
```

It is quite easy to see that the S-1 validation loop satisfies VALIDAFTER(j,k) because every transaction is validated after previous executions complete.  However, it is quite wasteful in resources, each loop fully executing/validating all transactions.

The first improvement is to replace both phases with parallel task-*stealing* by threads. Using insight from S-1, we distinguish between a preliminary execution (correponding to phase 1) and re-execution (following a validation abort).  Stealing is coordinated
via two synchronization counters, one per task type, `nextPrelimExecution` (initially 1) and `nextValidation` (initially 2). Each synchronizer `x` supports atomic procedures `x.increment() { oldVal := x; increment x; return oldVal } `and `x.setMin(val) { x := min(val, x) }. `

The following strawman scheduler, S-2, utilizes a task stealing regime:


## **S-2:**

```
# per thread main loop: 
repeat {

    # if available, steal next validation task
    if nextValidation < nextPrelimExecution
        j := nextValidation.increment() ; if j < nextPrelimExecution, validate TXj

    # if available, steal next execution task
    otherwise if nextPrelimExecution <= n
        j := nextPrelimExecution.increment() ; if j <= n, execute TXj

} until nextPrelimExecution > n, nextValidation > n, and no task is still running

validation of TXj {
    re-read TXj read-set 
    if read-set differs from original read-set of the latest TXj execution 
        re-execute
}

execution of TXj {
    (re-)execute TXj
    nextValidation.setMin(j+1) 
}
```


Interleaving preliminary executions with validations avoids unnecessary work executing transactions that might follow aborted transactions. 
Recall the running scenario above with block B that has dependencies 
TX1 &rarr; TX2 &rarr; TX3, TX4 &rarr; TX5 &rarr; TX6, TX7 &rarr; TX8 &rarr; TX9.
It is hard to lay out an exact timing of task teak stealing, because it depends on real-time latency and interleaving of validation and execution tasks. Notwithstanding, below is a possible execution of S-2 over B with four threads that exhibits
fewer (re-)executions and lower overall latency than S-1.

```
Possible time steps S-2 goes through with four threads:
  1. parallel execution of TX1, TX2, TX3, TX4; validation of TX2, TX3 fail; `nextValidation` set to 3      
  2. parallel execution of TX2, TX3, TX5, TX6; validation of TX3, TX6 fail; `nextValidation` set to 4      
  3. parallel execution of TX3, TX6, TX7, TX8; validation of TX8 fails; `nextValidation` set to 9      
  4. parallel execution of TX8, TX9, TX10; validation of TX9 fails; `nextValidation` set to 10      
  5. parallel execution of TX9; all validations succeed
```


Importantly, **VALIDAFTER(j, k)** is preserved because upon (re-)execution of a TXj, it decreases `nextValidation` to j+1. This guarantees that every k > j will be validated after the j execution. 

Preserving **READLAST(k)** requires care due to concurrent task stealing, since multiple *incarnations* of the same transaction validation or execution tasks may occur simultaneously. Recall that **READLAST(k)** requires that a read by a TXk should obtain the value recorded by the latest invocation of a TXj with the highest j &lt; k. This requires to synchronize transaction invocations, such that **READLAST(k)** returns the highest incarnation value recorded by a transaction. A simple solution is to use per-transaction atomic incarnation synchronizer that prevents stale incarnations from recording values.

The last improvement step consists of two important improvements.

The first is an extremely simple dependency tracking (no graphs or partial orders) that considerably reduces aborts. When a TXj aborts, the write-set of its latest invocation is marked `ABORTED`. READLAST(k) supports the `ABORTED` mark guaranteeing that a higher-index TXk reading from a location in this write-set will delay until the TXj completes re-executing.

The second one increases re-validation parallelism. When a transaction aborts, rather than waiting for it to complete re-execution, it decreases `nextValidation` immediately; then, if the re-execution writes to a (new) location which is not marked `ABORTED`, `nextValidation` is decreased again when the re-execution completes. 

The final scheduling algorithm S-3, has the same main loop body at S-2 with executions 
supporting dependency managements via `ABORTED` tagging, and with early re-validation enabled by decreasing `nextValidation` upon abort:

## **S-3:**


```
# per thread main loop, same as S-2
...

validation of TXj:
{
    re-read TXj read-set 
    if read-set differs from original read-set of the latest TXj execution 
        mark the TXj write-set ABORTED
        nextValidation.setMin(j+1) 
        execute TXj
}

execution of TXj:  
{
    (re-)execute TXj
    if the TXj write-set contains locations not marked ABORTED
        nextValidation.setMin(j+1) 
}
```

S-3 enhances efficiency through simple, on-the-fly dependency management using the `ABORTED` tag. For our running example of block B, 
An execution driven by S-3 with four threads may be able to avoid several of the re-executions incurred in S-2 by waiting on an ABORTED mark. 
Despite the high-contention B scenario, a possible execution of S-3 may achieve very close to optimal scheduling as shown below.

```
possible time steps S-3 goes through with four threads:
  1. parallel execution of TX1, TX2, TX3, TX4; validation of TX2, TX3 fail; `nextValidation` set to 3      
  2. parallel execution of TX2, TX5, TX6, TX7; execution of TX3 suspends on `ABORTED` by TX2; validation of TX6 fails; `nextValidation` set to 7
  3. parallel execution of TX3, TX6, TX8, TX9; validation of TX9 fails;`nextValidation` set to 10
  4. parallel execution of TX9, TX10; all validations succeed
```

The reason S-3 preserves **VALIDAFTER(j, k)** is slightly subtle. Suppose that TXj &rarr; TXk.
Recall, when TXj fails, S-3 lets (re-)validations of TXk, k > j, proceed before TXj completes re-execution. There are two possible cases. If a TXk-validation reads an `ABORTED` value of TXj, it will wait for TXj to complete; and if it reads a value which is not marked `ABORTED` and the TXj re-execution overwrites it, then TXk will be forced to revalidate again.

>> *Disclaimer: The description above reflects more-or-less faithfully the Block-STM approach; for details, see the [paper](https://arxiv.org/pdf/2203.06871.pdf) (note, the description above uses different names from the paper, e.g., `ABORTED` replaces “ESTIMATE”, `nextPrelimExecution` replaces “execution_idx”, `nextValidation` replaces “validation_idx”).*

## Conclusion

Through a careful combination of simple, known techniques and applying them to a pre-ordered block of transactions that commit at bulk, 
Block-STM enables effective speedup of smart contract parallel processing. Simplicity is a virtue of Block-STM, not a failing, enabling a robust and stable implementation. 
Block-STM has been integrated within the Diem blockchain core ([https://github.com/diem/](https://github.com/diem/)) and evaluated on synthetic transaction workloads, yielding over 17x speedup on 32 cores under low/modest contention. 

