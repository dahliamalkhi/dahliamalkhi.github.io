[Block-STM](https://arxiv.org/pdf/2203.06871.pdf) is an exciting technology that accelerates smart-contract execution, emanating from the Diem project
and recently enhanced by Aptos Labs and integrated into [aptos-core](https://github.com/aptos-labs/aptos-core). 

## How it all started

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

## Overview

Block-STM is a parallel execution engine for smart contracts, built around the principles of Software Transactional Memory. 
Transactions are grouped in blocks, each block containing a pre-ordered sequence of transactions
TX1, TX2, ..., TXn. Transactions consist of smart-contract code that reads and writes to shared memory and their
execution results in a read-set and a write-set: the read-set consists of pairs, a memory location and the transaction that wrote it; the write-set consists of pairs, a memory location and a value, that the transaction would record if it became committed.

A parallel execution of the block must yield the same deterministic outcome 
that preserves a block pre-order, namely, it results in exactly the same read/write sets as a sequential execution. 
More specifically, 
in a sequential execution, a read by TXk from a particular memory location obtains the value writted by the highest TXj, where j < k, to the location, if exists; or the initial value at that memory location when the block execution started, if none. 

A scenario serving as a running example throughout this post is a block B consisting of ten transactions TX1-TX10, each TXj doing `{ M[j mod 4] := M[j mod 4] + 1 }`. If in a sequential execution, TXk reads a value written by TXj,
we denote this as a read/write dependency TXj &rarr; TXk. 
B has the following read/write dependencies:

> TX1 &rarr; TX4 &rarr; TX6 &rarr; TX8 &rarr; TX9   

> TX2 &rarr; TX5 &rarr; { TX7 , TX10 }

A parallel execution must guarantee that all transactions indeed read values adhering to these dependencies.
Block-STM uses an optimistic approach, executing tranascations greedily and optimistically in parallel and then validating their read-set, 
potentially causing abort/re-execute. 

Correct optimism revolves around maintaining two principles:

* **VALIDAFTER(j, k)**: For every j,k, such that j < k, a validation of TXk is performed after TXj executes (or re-executes).
* **READLAST(k)**: Whenever TXk executes (speculatively), a read by TXk obtains the value recorded so far by the highest transaction TXj preceding it, i.e., where j < k. Higher transactions TXl, where l > k, do not intefer with TXk. 

Jointly, these two principles 
suffice to guarantee both safety and liveness no matter what scheduling policy is used, so long as required execution and validation tasks are eventually dispatched. Safety follows because a TXk gets validated after all TXj, j &lt; k, are finalized. Liveness follows by induction. Initially transaction 1 is guaranteed to pass validation successfully and not require re-execution. Once transactions TX1-TXj have successfully validated, the next invocation of transaction j+1 will pass validation successfully and not require re-execution.

**READLAST(k)** is achieved via a simple multi-version in-memory data structure that keeps versioned write-sets, TXj recording values whose version is j. 
A read by TXk obtains the value recorded by the latest invocation of TXj with the highest j &lt; k.

A special value `ABORTED` may be stored at version j when the latest invocation of TXj aborts. 
If TXk reads this value, it suspends and resumes when the value becomes set.  

**VALIDAFTER(j, k)** is implemented by a scheduler. For each j, every TXk with index k > j is scheduled for (re)validation after TXj completes (re-)execution. Validation re-reads the read-set of the TXk and compares against the original read-set that TXk obtained in its latest execution. If validation fails, TXk re-executes.

## Scheduling

It remains to focus on devising an efficient schedule for parallelizing execution and validations. We will construct an effective scheduling strategy gradually, starting with a correct but inefficient strawman and gradually improving it in four steps. Readers may skip directly to “S-4” at the bottom, where the full scheduling strategy is described in under 20 lines of pseudo-code, and come back here as needed for a step-by-step construction. 

 

At a first cut, consider the following strawman scheduler, S-1.


## **S-1:**


```
Phase 1:                # execution
    parallel execute all transactions 1..n

Phase 2:                # validation
    repeat
        parallel validate all transactions
    until all validations pass

Validation of Txj:
    re-read TXj read-set 
    if read-set differs from original read-set of the latest TXj execution 
        re-execute TXj 
```


The S-1 schedule has two phases. Phase 1 executes all transactions optimistically in parallel. Phase 2 repeatedly validates all transactions in parallel, re-executing those that fail, until there are no more validation failures. 

Recall our example block B, with dependencies TX1 &rarr; TX4 &rarr; TX6 &rarr; TX8 &rarr; TX9, TX2 &rarr; TX5 &rarr; { TX7 , TX10 }. S-1 will perform the following steps:

Phase 1:
> parallel execution of all transactions

Phase 1:
> parallel validation of all transactions; 4-10 fail and re-execute 

> parallel validation of all transactions; 6-10 fail and re-execute 

> parallel validation of all transactions; 8-9 fail and re-execute 

> parallel validation of all transactions; 9 fail and re-execute 

> parallel validation of all transactions; all succeed

It is quite easy to see that the S-1 validation loop satisfies VALIDAFTER(j,k) because every transaction is validate after previous executions complete.  However, the full validation in each iteration of the validation loop is wasteful.

The first improvement is to replace phase 2 with a parallel task-*stealing* regime, coordinated
via a single synchronization counter `nextValidation` that supports atomic procedures `nextValidation.increment() { oldVal := nextValidation; increment nextValidation; return oldVal } `and `nextValidation.setMin(val) { nextValidation := min(val, nextValidation) }. `

Replacing the validation-loop in phase 2 with a task-stealing loop results the following strawman scheduler, S-2:


## **S-2:**


```
Phase 1:                # execution
    parallel execute all transactions 1..n

Phase 2:                # validation
    nextValidation.initialize(2)

    repeat 
        j := nextValidation.increment() ; if j > n, go back to loop 
        validate TXj
    until nextValidation > n and no task is still running

Validation of TXj:
        re-read TXj read-set 
        if read-set differs from original read-set of the latest TXj execution 
            re-execute TXj
            nextValidation.setMin(j+1) 
```


The S-2 task-stealing regime is more efficient than the S-1 validation loop, because it 
decreases `nextValidation` immediately upon validation failure, allowing higher index re-validations to commence. With task stealing, it is hard to predict an exact execution transcript, it depends on the latency and interleaving of validation and execution tasks. A possible execution with 2 threads may result in the following transcript:

Phase 1:
> parallel execution of all transactions, 2 at a time

Phase 2:

> validation of TX2-TX3; all succeed

> validation of TX4-TX5; both fail and re-execute, `nextValidaton` set to 5

> validation of TX5-TX6; 5 succeeds, 6 fails and re-executes, `nextValidaton` set to 7

> validation of TX7-TX8; both fail and re-execute, `nextValidaton` set to 8

> validation of TX8-TX9; 8 succeeds, 9 fails and re-executes, `nextValidaton` set to 9

> validation of TX9-TX10; both succeed

Importantly, **VALIDAFTER(j, k)** is preserved because upon (re-)execution of a TXj it decreases `nextValidation` to j. This guarantees that every k > j will be validated after the j execution. 

Preserving **READLAST(k)** is more challenging due to concurrent task stealing, since multiple *incarnations* of the same transaction validation or execution tasks may occur simultaneously. Recall that **READLAST(k)** requires that a read by a TXk should obtain the value recorded by the latest invocation of a TXj with the highest j &lt; k. This requires to synchronize transaction invocations, such that **READLAST(k)** returns the highest incarnation value recorded by a transaction. A simple solution is to use per-transaction atomic incarnation synchronizer that prevents stale incarnations from recording values.

Next, we remove the two phases altogether, removing the preliminary transaction execution loop and allowing threads to steal preliminary execution tasks simultaneously with validations. Execution task stealing is managed using another synchronization counter `nextPrelimExecution`. Validation stealing only waits for corresponding tasks to complete, rather than waiting for all preliminary execution to complete. This improves performance since early detection of conflicts, especially in low-index transactions, can prevent aborts later. 

A strawman scheduler, S-3, that supports interleaved execution/validation works as follows:


## **S-3:**


```
nextPrelimExecution.initialize(1) 
nextValidation.initialize(2) 

per thread main loop:

    if nextPrelimExecution > n, nextValidation > n, and no task is still running, exit loop

    if nextValidation < nextPrelimExecution                 # schedule validation
        j := nextValidation.increment() ; if j >= nextPrelimExecution, go back to loop
        re-read TXj read-set 
        if read-set differs from original read-set of the latest TXj execution 
            goto execute

    otherwise if nextPrelimExecution <= n             # schedule execution
        j := nextPrelimExecution.increment() ; if j > n, go back to loop

    otherwise go back to loop

execute:
    (re-)execute TXj
    nextValidation.setMin(j+1) 
```

Interleaving preliminary executions in S-3 with validations avoids unnecessary work executing transactions that succeed aborted ones. For example, in the running scenario above, a batch of preliminary executions may contain transaction 1-4. Validations will be scheduled immediately when their execution completes. When the 4 aborts and re-executes, no higher transaction execution will have been wasted. 

The last improvement step consists of two important improvements.

The first is an extremely simple dependency tracking (no graphs or partial orders) that considerably reduces aborts. When a TXj aborts, the write-set of its latest invocation is marked `ABORTED`. READLAST(k) supports the `ABORTED` mark guaranteeing that a higher-index TXk reading from a location in this write-set will delay until the TXj completes re-executing.

The second one increases re-validation parallelism. When a transaction aborts, rather than waiting for it to complete re-execution, it decreases `nextValidation` immediately; then, if the re-execution writes to a (new) location which is not marked `ABORTED`, `nextValidation` is decreased again when the re-execution completes. 

The final scheduling algorithm S-4, 
that supports interleaved execution/validation and dependency managements utilizing `ABORTED` tagging,
is captured in full in under one page as follows:

## **S-4:**


```
nextPrelimExecution.initialize(1) 
nextValidation.initialize(2) 

per thread main loop:

     if nextPrelimExecution > n, nextValidation > n, and no task is still running, exit loop

     if nextValidation < nextPrelimExecution                 # schedule validation
         j := nextValidation.increment() ; if j >= nextPrelimExecution, go back to loop
         re-read TXj read-set 
         if read-set differs from original read-set of the latest TXj execution 
             mark the TXj write-set ABORTED
             nextValidation.setMin(j+1) 
             goto execute

     otherwise if nextPrelimExecution <= n             # schedule execution
         j := nextPrelimExecution.increment() ; if j > n, go back to loop

     otherwise go back to loop

execute:  
     (re-)execute TXj
     if the TXj write-set contains locations not marked ABORTED
         nextValidation.setMin(j+1) 
```


S-4 lets re-validations of TXk, k > j,  proceed early while preserving **VALIDAFTER(j, k)**: if a TXk validation reads an `ABORTED` value, it has to wait; and if it reads a value which is not marked `ABORTED` and the j re-execution overwrites it, the TXk will be forced to revalidate again.

S-4 enables essentially unbounded parallelism. It reflects more-or-less faithfully the [Block-STM](https://arxiv.org/pdf/2203.06871.pdf) approach; for details, see the paper (note, the description above uses different names from the paper, e.g., `ABORTED` replaces “ESTIMATE”, `nextPrelimExecution` replaces “execution_idx”, `nextValidation` replaces “validation_idx”). Block-STM has been implemented within the Diem blockchain core ([https://github.com/diem/](https://github.com/diem/)) and evaluated on synthetic transaction workloads, yielding over 17x speedup on 32 cores under low/modest contention. 

