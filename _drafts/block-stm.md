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

The focus of this work is an input block containing a pre-ordered sequence of transactions
tx-1, tx-2, ..., tx-n. Transactions consist of smart-contract code that reads and writes to shared memory. 

An example serving as a running example throughout this post is a block B consisting of ten transactions tx-1, tx-2, ..., tx-10, tx-j reading from mememory location M[j mod 3] and writing to location M[j mod 4]: 

```
tx-j:
{ 
    if (read M[j mod 3] > 0) 
        M[j mod 4] := M[j mod 3] + 1 
}
```

A transaction execution results in a read-set and a write-set. The read-set consists of pairs, a memory location and the transaction that wrote it. The write-set consists of pairs, a memory location and a value, that the transaction would record if it became committed.

In a sequential execution, a read by tx-k from a particular memory location obtains the value writted by the highest tx-j, where j < k, to the location; or the initial value at that memory location when the block execution started if none. We denote this dependency as tx-k &larr; tx-j. 
For example, in a sequential execution of B, tx[1] reads M[1] and writes M[1], respectively; tx-4 reads M[1] and writes M[0], hence 
tx-4 &larr; tx-1; 
tx-5 &larr; tx-2; 
tx-6 &larr; tx-4; 
tx-7 &larr; tx-5; 
tx-8 &larr; tx-6; 
tx-9 &larr; tx-8; 
tx-10 &larr; tx-5. 

The goal is to enable parallel execution that preserves a block pre-order, namely,
results in exactly the same read/write sets as a sequential execution. 
This is accomplished via optimistic execution, followed by validation that may lead to a commit or abort/re-execute. The strategy for supporting efficient optimism revolves around two mechanisms, validation and multi-version concurrency control:

* **VALID(j, k)**: For every j,k, such that j < k, a validation of tx-k is performed after tx-j executes (or re-executes).
* **MVCC**: Whenever tx-k executes (speculatively), a read by tx-k obtains the value recorded so far by the highest transaction tx-j preceding it, i.e., where j < k. Higher transactions tx-l, where l > k, do not intefer with tx-k. 

Jointly, these two principles 
suffice to guarantee both safety and liveness no matter what scheduling policy is used, so long as required execution and validation tasks are eventually dispatched. Safety follows because a tx-k gets validated after all tx-j, j &lt; k, are finalized. Liveness follows by induction. Initially transaction 1 is guaranteed to pass validation successfully and not require re-execution. Once transactions 1..j have successfully validated, the next invocation of transaction j+1 will pass validation successfully and not require re-execution.

**MVCC** is achieved via a simple multi-version in-memory data structure that keeps versioned write-sets, tx-j recording values whose version is j. 
A read by tx-k obtains the value recorded by the latest invocation of tx-j with the highest j &lt; 

A special value `ABORTED` may be stored at version j when the latest invocation of tx-j aborts. 
If tx-k reads this value, it suspends and resumes when the value becomes set.  

**VALID(j, k)** is implemented by a scheduler. For each j, every tx-k with index k > j is scheduled for (re)validation after tx-j completes (re-)execution. Validation re-reads the read-set of the tx-k and compares against the original read-set that tx-k obtained in its latest execution. If validation fails, tx-k re-executes.

## Scheduling

It remains to focus on devising an efficient schedule for parallelizing execution and validations. We will construct an effective scheduling strategy gradually, starting with a correct but inefficient strawman and gradually improving it in four steps. Readers may skip directly to “S-4” at the bottom, where the full scheduling strategy is described in under 20 lines of pseudo-code, and come back here as needed for a step-by-step construction. 

 

At a first cut, consider the following strawman scheduler, S-1.


## **S-1:**


```
Phase 1:                # execution
    parallel execute all transactions 1..n

Phase 2:                # validation
    validation loop:
        parallel-do for all j in [ nextValidation..n ] :
            re-read tx-j read-set 
            if read-set differs from original read-set of the latest tx-j execution 
                re-execute tx-j 
            if any tx-j failed validation
                update nextValidation to j+1, where j is the minimal failed transaction
            otherwise
                exit loop  
```


The S-1 schedule has two phases. Phase 1 executes all transactions optimistically in parallel. Phase 2 repeatedly validates all remaining validations in parallel, re-executing transations that fail.
The first iteration validates all transactions; some may fail validation and will be re-executed. The next iteration re-validates all transactions higher than the lowest failing index; some may fail and re-execute. And so on, until there are no more validation failures. 

For example, say that a block has ten transactions 1..10, and transaction pairs (1,4), (4,7) and (7,8) are conflicting. The first iteration of the validation-loop performs validations of 2..10; the validations of 4, 7 and 8 will fail. The second iteration re-validates 5..10 and 7, 8 fail. In a third iteration, 7..10 re-validate and 8 fails. Finally in a fourth iteration, validations 8..10 succeed.

It is quite easy to see that the S-1 validation loop ends after at most n iterations, because in each iteration, nextValidation advances by at least 1. 

However, both the execution and validation loops are logically centrally coordinated. The first improvement is to get rid of central coordination in phase 2 by having threads *steal* validation tasks. Coordinating task-stealing is done 
using a single synchronization counter `nextValidation` that supports atomic procedures `nextValidation.increment() { oldVal := nextValidation; increment nextValidation; return oldVal } `and `nextValidation.setMin(val) { nextValidation := min(val, nextValidation) }. `

Replacing the above validation-loop in phase 2 with a task-stealing loop results the following strawman scheduler, S-2:


## **S-2:**


```
Phase 1:                # execution
    parallel execute all transactions 1..n

Phase 2:                # validation
    nextValidation.initialize(2)

    per thread main loop:
        if nextValidation > n, and no task is still running, exit loop
        j := nextValidation.increment() ; if j > n, go back to loop 

        re-read tx-j read-set 
        if read-set differs from original read-set of the latest tx-j execution 
            re-execute tx-j
            nextValidation.setMin(j+1) 
```


The S-2 task-stealing regime is more efficient than the S-1 validation loop, because it decreases `nextValidation` immediately upon validation failure, allowing higher index re-validations to commence. For example, in the scenario above, when the validation of 4 fails, re-validation of 5..10 will start right away, 7 will fail validation and re-execute only once, and similarly 8. 

Importantly, **VALID(j, k)** is preserved because upon (re-)execution of a tx-j it decreases `nextValidation` to j. This guarantees that every k > j will be validated after the j execution. 

Concurrent task stealing creates a challenge since multiple *incarnations* of the same transaction validation or execution tasks may occur simultaneously. Recall that **MVCC** requires that a read by a tx-k should obtain the value recorded by the latest invocation of a tx-j with the highest j &lt; k. This requires to synchronize transaction invocations, such that **MVCC** returns the **highest incarnation** value recorded by a transaction. A simple solution is to use a x-r atomic incarnation synchronizer that prevents stale incarnations from recording values.

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
        re-read tx-j read-set 
        if read-set differs from original read-set of the latest tx-j execution 
            goto execute

    otherwise if nextPrelimExecution <= n             # schedule execution
        j := nextPrelimExecution.increment() ; if j > n, go back to loop

    otherwise go back to loop

execute:
    (re-)execute tx-j
    nextValidation.setMin(j+1) 
```

Interleaving preliminary executions in S-3 with validations avoids unnecessary work executing transactions that succeed aborted ones. For example, in the running scenario above, a batch of preliminary executions may contain transaction 1..4. Validations will be scheduled immediately when their execution completes. When the tx-4 aborts and re-executes, no higher transaction execution will have been wasted. 

The last improvement step consists of two important improvements.

The first is an extremely simple dependency tracking (no graphs or partial orders) that considerably reduces aborts. When a tx-j aborts, the write-set of its latest invocation is marked `ABORTED`. MVCC supports the `ABORTED` mark guaranteeing that a higher-index tx-k reading from a location in this write-set will delay until the tx-j completes re-executing.

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
         re-read tx-j read-set 
         if read-set differs from original read-set of the latest tx-j execution 
             mark the tx-j write-set ABORTED
             nextValidation.setMin(j+1) 
             goto execute

     otherwise if nextPrelimExecution <= n             # schedule execution
         j := nextPrelimExecution.increment() ; if j > n, go back to loop

     otherwise go back to loop

execute:  
     (re-)execute tx-j
     if the tx-j write-set contains locations not marked ABORTED
         nextValidation.setMin(j+1) 
```


S-4 lets re-validations of tx-k, k > j,  proceed early while preserving **VALID(j, k)**: if a tx-k validation reads an `ABORTED` value, it has to wait; and if it reads a value which is not marked `ABORTED` and the j re-execution overwrites it, the tx-k will be forced to revalidate again.

S-4 enables essentially unbounded parallelism. It reflects more-or-less faithfully the [Block-STM](https://arxiv.org/pdf/2203.06871.pdf) approach; for details, see the paper (note, the description above uses different names from the paper, e.g., `ABORTED` replaces “ESTIMATE”, `nextPrelimExecution` replaces “execution_idx”, `nextValidation` replaces “validation_idx”). Block-STM has been implemented within the Diem blockchain core ([https://github.com/diem/](https://github.com/diem/)) and evaluated on synthetic transaction workloads, yielding over 17x speedup on 32 cores under low/modest contention. 

