[Block-STM](https://arxiv.org/pdf/2203.06871.pdf) is an exciting technology 
that accelerates smart-contract execution, emanating from the Diem project
and recently enhanced by Aptos Labs and integrated into [aptos-core](https://github.com/aptos-labs/aptos-core), 

## How it all started

Much of what follows The foundation of Block-STM is 

An approach pioneered in the [Calvin](http://cs.yale.edu/homes/thomson/publications/calvin-sigmod12.pdf) and [Bohm](https://arxiv.org/pdf/1412.2324.pdf) projects in the context of distributed databases is the foundation of much of what follows. The insightful idea in those projects is to simplify concurrency management by disseminating pre-ordered batches (akin to blocks) of transactions along with pre-estimates of their read- and write- sets. 
Every database partition can then autonomously execute transactions according to the block in pre-order, each transaction
waiting only for read dependencies on earlier transactions in the block. The [first DiemVM parallel executor](https://github.com/diem/diem/issues/8829) implements this approach but it relies on a static transaction analyzer to pre-estimate read/write-sets which is time consuming. 

Another work provides a link from traditional database concurrency to smart-contract parallelism [Dickerson et al](https://arxiv.org/abs/1702.04467). In that work, a consensus *leader* (or *miner*) pre-computes a parallel execution serialization
harnessing optimistic software transactional memory (STM) (a later work [OptSmart](https://arxiv.org/abs/2102.04875) added read/write-set dependency tracking) and disseminates the resulting serialization as a “fork-join” schedule to all "validator" nodes. Those approaches
remove the reliance on static transaction analysis but require a leader to pre-execute blocks.

The Block-STM parallel executor combines the pre-ordered block idea with optimistic STM to enforce the block pre-order of transactions on-the-fly, completely removing the need to pre-disseminate an execution schedule or pre-compute transaction dependencies, while guaranteeing repeatability.

## Block-STM Overview

This post explains the construction of an efficient parallel execution that preserves block pre-order utilizing two key tenets: 


* **MVCC**: An in-memory data structure keeps versioned write-sets, the j-transaction storing values whose version is j. A special value ABORTED may be stored at version j when the latest invocation of j-transaction aborts. A read by k-transaction obtains the value recorded by the latest invocation of a j-transaction with the highest j &lt; k (or the k-transaction suspends on an ABORTED value and resumes when the value becomes set).  


* **SAFETY(j, k)**: When a j-transaction executes (or re-executes), every k-transaction with index k > j has to (re)validate after the j-transaction completes execution. Validation re-reads the read-set of the k-transaction and compares against the original read-set the k-transaction obtained in its latest execution. If validation fails, the k-transaction needs to re-execute.

Together, MVCC and SAFETY(j, k) suffice to guarantee safety and liveness no matter what scheduling policy is used, so long as execution and validation tasks are eventually dispatched. Safety follows because a k-transaction gets validated after all j-transactions, j &lt; k, are finalized. Liveness follows by induction. Initially transaction 1 is guaranteed to pass validation successfully and not require re-execution. Once transactions 1..j have successfully validated, the next invocation of transaction j+1 will pass validation successfully and not require re-execution.

## Scheduling

It remains to focus on devising an efficient schedule for parallelizing execution and validations. We will construct an effective scheduling strategy gradually in four steps; readers may skip to “S-4” at the bottom, where the full scheduling strategy is described in under 20 lines of pseudo-code, and come back here as needed for step-by-step construction. 

 

At a first cut, consider the following scheduler, let’s call it S-1.


## **S-1:**


```
parallel execute all transactions 1..n

nextValidation := 2 

validation loop:
    parallel-do for all j in [ nextValidation..n ] :
        re-read j-transaction read-set 
        if read-set differs from original read-set of the latest j-transaction execution 
            re-execute j-transaction 
        if any j-transaction failed validation
            update nextValidation to j+1, where j is the minimal failed transaction
        otherwise
            exit loop  
```


The S-1 schedule first executes all transactions optimistically in parallel. It then iterates over waves of parallel validations. The first iteration validates all transactions; some may fail validation and will be re-executed. The next wave re-validates all transactions higher than the lowest failing index; some may fail and re-execute. And so on, until there are no more validation failures. 

For example, say that a block has ten transactions 1..10, and transaction pairs (1,4), (4,7) and (7,8) are conflicting. The first iteration of the validation-loop performs validations of 1..10; the validations of 4, 7 and 8 will fail. The second iteration re-validates 5..10 and 7, 8 fail. In a third iteration, 7..10 re-validate and 8 fails. Finally in a fourth iteration, validations 8..10 succeed.

It is quite easy to see that the S-1 validation loop ends after at most n iterations, because in each iteration, nextValidation advances by at least 1. 

However, both the execution and validation loops are logically centrally coordinated. The first improvement is to get rid of the centrally coordinated validation-loop using a single synchronization counter `nextValidation` that supports atomic procedures `ValidTo.increment() { oldVal := ValidTo; increment ValidTo; return oldVal } `and `ValidTo.setMin(val) { ValidTo := min(val, ValidTo) }. `

 

Replacing the above validation-loop, we write a task-stealing loop at each thread, resulting the following scheduler called S-2:


## **S-2:**


```
parallel execute all transactions 1..n

nextValidation.initialize(2)

per thread main loop:
    if nextValidation > n, and no task is still running, exit loop
    j := nextValidation.increment() ; if j > n, go back to loop 

    re-read j-transaction read-set 
    if read-set differs from original read-set of the latest j-transaction execution 
        re-execute j-transaction
        nextValidation.setMin(j+1) 
```


The S-2 task-stealing regime is more efficient than the S-1 validation loop, because it decreases `nextValidation` immediately upon validation failure, allowing higher index re-validations to commence. For example, in the scenario above, when the validation of 4 fails, re-validation of 5..10 will start right away, 7 will fail validation and re-execute only once, and similarly 8. 

Concurrent task stealing creates a challenge since multiple "incarnations" of the same transaction validation or execution tasks may occur simultaneously. Recall that MVCC requires that a read by a k-transaction should obtain the value recorded by the latest invocation of a j-transaction with the highest j &lt; k. This requires to synchronize transaction invocations, such that MVCC returns the **highest incarnation** value recorded by a transaction. A simple solution is to use a per-transaction atomic incarnation synchronizer, which also allows optimizations like preventing stale incarnations from recording values (for details, see the paper).

Importantly, SAFETY(j, k) is preserved because upon (re-)execution of a j-transaction it decreased `ValidTo `to j. This guarantees that every k > j will be validated after the j execution. 

Next we tackle the preliminary transaction execution loop, allowing threads to steal preliminary execution tasks using another synchronization counter nextPrelimExecution that tracks preliminary transaction invocations. However, rather than waiting for all preliminary execution to complete to start validation, we will interleave them with validation. This improves performance since early detection of conflicts, especially in low-index transactions, can prevent aborts later. 

The interleaved scheduler supporting ABORTED is called S-3 and works as follows:


## **S-3:**


```
nextPrelimExecution.initialize(1) 
nextValidation.initialize(2) 

per thread main loop:

    if nextPrelimExecution > n, nextValidation > n, and no task is still running, exit loop

    if nextValidation < nextPrelimExecution                 # schedule validation
        j := nextValidation.increment() ; if j >= nextPrelimExecution, go back to loop
        re-read j-transaction read-set 
        if read-set differs from original read-set of the latest j-transaction execution 
            goto execute

    otherwise if nextPrelimExecution <= n             # schedule execution
        j := nextPrelimExecution.increment() ; if j > n, go back to loop

    otherwise go back to loop

execute:
    (re-)execute j-transaction
    nextValidation.setMin(j+1) 
```

Interleaving preliminary executions in S-3 with validations avoids unnecessary work executing transactions that succeed aborted ones. For example, in the running scenario above, a batch of preliminary executions may contain transaction 1..4. Validations will be scheduled immediately when their execution completes. When the 4-transaction aborts and re-executes, no higher transaction execution will have been wasted. 

The last improvement step consists of two important improvements.

The first is an extremely simple dependency tracking (no graphs or partial orders) that considerably reduces aborts. When a j-transaction aborts, the write-set of its latest invocation is marked ABORTED. Since MVCC already supported the ABORTED mark, a higher-index k-transaction reading from a location in this write-set will delay until the j-transaction completes re-executing.

The second one increases re-validation parallelism. When a transaction aborts, rather than waiting for it to complete re-execution, it decreases nextValidation immediately; then if the re-execution writes to a (new) location which is not marked ABORTED, ValidTo is decreased again when the re-execution completes. 

The final scheduling algorithm, S-4, is captured abstractly in full in under one page as follows:


## **S-4:**


```
nextPrelimExecution.initialize(1) 
nextValidation.initialize(2) 

per thread main loop:

     if nextPrelimExecution > n, nextValidation > n, and no task is still running, exit loop

     if nextValidation < nextPrelimExecution                 # schedule validation
         j := nextValidation.increment() ; if j >= nextPrelimExecution, go back to loop
         re-read j-transaction read-set 
         if read-set differs from original read-set of the latest j-transaction execution 
             mark the j-transaction write-set ABORTED
             nextValidation.setMin(j+1) 
             goto execute

     otherwise if nextPrelimExecution <= n             # schedule execution
         j := nextPrelimExecution.increment() ; if j > n, go back to loop

     otherwise go back to loop

execute:  
     (re-)execute j-transaction
     if the j-transaction write-set contains locations not marked ABORTED
         nextValidation.setMin(j+1) 
```


S-4 lets re-validations of k-transactions, k > j,  proceed early while preserving SAFETY(j, k): if a k-transaction validation reads an ABORTED value, it has to wait; and if it reads a value which is not marked ABORTED and the j re-execution overwrites it, the k-transaction will be forced to revalidate again.

S-4 enables essentially unbounded parallelism. It reflects more-or-less faithfully the [Block-STM](https://arxiv.org/pdf/2203.06871.pdf) approach; for details, see the paper (note, the description above uses different names from the paper, e.g., ABORTED replaces “ESTIMATE”, nextPrelimExecution replaces “execution_idx”, nextValidation replaces “validation_idx”). Block-STM has been implemented within the Diem blockchain core ([https://diem/diem](https://diem/diem)) and evaluated on synthetic transaction workload, yielding over 17x speedup on 32 cores under low/modest contention. 

