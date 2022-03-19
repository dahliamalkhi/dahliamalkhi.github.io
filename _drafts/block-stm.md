<!-----

Yay, no errors, warnings, or alerts!

Conversion time: 0.626 seconds.


Using this Markdown file:

1. Paste this output into your source file.
2. See the notes and action items below regarding this conversion run.
3. Check the rendered output (headings, lists, code blocks, tables) for proper
   formatting and use a linkchecker before you publish this page.

Conversion notes:

* Docs to Markdown version 1.0β33
* Sat Mar 19 2022 10:21:48 GMT-0700 (PDT)
* Source doc: Block-STM post [03-19-2022]
----->


[Block-STM](https://arxiv.org/pdf/2203.06871.pdf) is an exciting innovation emanating from the Diem project, recently enhanced by Aptos and integrated into [aptos-core](https://github.com/aptos-labs/aptos-core), that accelerates smart-contract execution. 

The Block-STM approach builds on an approach which was pioneered in the [Calvin](http://cs.yale.edu/homes/thomson/publications/calvin-sigmod12.pdf) and [Bohm](https://arxiv.org/pdf/1412.2324.pdf) projects, driving repeated parallel execution by forming pre-ordered batches (akin to blocks) of transactions that execute in parallel as soon as their read dependencies are resolved;  pre-ordering provides repeatable execution. Later, [Dickerson et al](https://arxiv.org/abs/1702.04467) harnessed software transactional memory (STM) to pre-determine a serialization order as a “fork-join” schedule. Unlike these previous approaches, Block-STM completely removes the need to pre-execute and pre-determine transaction dependencies. Repeatability stems from guaranteeing that the result of the parallel execution is identical with executing transactions in their block pre-order, one after another. 

This post explains the construction of an efficient parallel execution that preserves block pre-order utilizing two key tenets: 


* **MVCC**: An in-memory data structure keeps versioned write-sets, the j-transaction storing values whose version is j. A special value ABORTED may be stored at version j when the latest invocation of j-transaction aborts. A read by k-transaction obtains the latest value recorded by a j-transaction with j &lt; k (or the k-transaction suspends on an ABORTED value and resumes when the value becomes set).  


* **SAFETY(j, k)**: When a j-transaction executes (or re-executes), every k-transaction with index k > j has to (re)validate after the j-transaction completes execution. Validation re-reads the read-set of the k-transaction and compares against the original read-set the k-transaction obtained in its latest execution. If validation fails, the k-transaction needs to re-execute.

Together, MVCC and SAFETY(j, k) suffice to guarantee safety and liveness no matter what scheduling policy is used, so long as execution and validation tasks are eventually dispatched. Safety follows because a k-transaction gets validated after all j-transactions, j &lt; k, are finalized. Liveness follows by induction. Initially transaction 1 is guaranteed to pass validation successfully and not require re-execution. Once transactions 1..j have successfully validated, the next invocation of transaction j+1 will pass validation successfully and not require re-execution.

It remains to focus on devising an efficient schedule for parallelizing execution and validations. We will construct an effective scheduling strategy gradually in four steps; readers may skip to “S-4” at the bottom, where the full scheduling strategy is described in under 20 lines of pseudo-code, and come back here as needed for step-by-step construction. 

 

At a first cut, consider the following scheduler, let’s call it S-1.


## **S-1:**


```
    parallel execute all transactions 1..n

    ValidTo := 0 

    Validation loop:
    Parallel-do for all j in [ (ValidTo+1)..n ] :
        re-read j-transaction read-set 
        If read-set differs from original read-set of the latest j-transaction execution 
            re-execute j-transaction 
        If any j-transaction failed validation
        Update ValidTo to the minimal failed j-transaction
        Otherwise
        Exit loop  
```


The schedule first executes all transactions optimistically in parallel. It then iterates over waves of parallel validations. The first iteration validates all transactions; some may fail validation and will be re-executed. The next wave re-validates all transactions higher than the lowest failing index; some may fail and re-execute. And so on, until there are no more validation failures. 

For example, say that a block has ten transactions 1..10, and transaction pairs (1,4) and (7,8) are conflicting. The first iteration of the validation-loop performs validations of 1..10; the validations of 4 and 8 fail. The second iteration re-validates 5..10 and 8 fails. In a third iteration, all validations succeed.

It is quite easy to see that the S-1 validation loop ends after at most n iterations, because in each iteration, ValidTo advances by at least 1. 

However, both the execution and validation loops are logically centrally coordinated. The first improvement is to get rid of the centrally coordinated validation-loop using a single synchronization counter `ValidTo` that supports atomic procedures `ValidTo.increment() { oldVal := ValidTo; increment ValidTo; return oldVal } `and `ValidTo.setMin(val) { ValidTo := min(val, ValidTo) }. `

 

Replacing the above validation-loop, we write a task-stealing loop at each thread, resulting the following scheduler called S-2:


## **S-2:**


```
    parallel execute all transactions 1..n

    <mark>ValidTo.initialize(0)</mark>

    Per thread main loop:
    	If ValidTo >= n, and no task is still running, exit loop

        j := ValidTo.increment() ; if j > n, go back to loop 
    re-read j-transaction read-set 
    If read-set differs from original read-set of the latest j-transaction execution 
        re-execute j-transaction
        ValidTo.setMin(j) 
```


The S-2 task-stealing regime is more efficient than the S-1 validation loop It decreases `ValidTo` immediately upon validation failure, allowing higher index re-validations to commence. For example, in the scenario above, when the validation of 4 fails, re-validation of 5..10 will start right away, 8 will fail validation and re-execute only once, and immediately following, 9..10 will re-validate successfully. Importantly, SAFETY(j, k) is preserved because upon (re-)execution of a j-transaction it decreased `ValidTo `to j. This guarantees that every k > j will be validated after the j execution. 

Next we tackle the initial transaction execution loop, allowing threads to steal initial execution tasks using another synchronization counter DoneTo that tracks first transaction invocations. However, rather than waiting for all initial execution to complete to start validation, we will interleave them with validation. This improves performance since early detection of conflicts, especially in low-index transactions, can prevent aborts later. 

The interleaved scheduler supporting ABORTED is called S-3 and works as follows:


## **S-3:**


```
    DoneTo.initialize(0) 
    ValidTo.initialize(0) 

    Per thread main loop:


    If DoneTo >= n, ValidTo >= n, and no task is still running, exit loop
    needExecution := false

    If ValidTo < DoneTo 				# validate
        j := ValidTo.increment() ; if j > n, go back to loop
        re-read j-transaction read-set 
        If read-set differs from original read-set of the latest j-transaction execution 
        	needExecution := true

    Otherwise if DoneTo < n 			# execute
        j := DoneTo.increment() ; if j > n, go back to loop
        if available
            needExecution := true

    if needExecution
        (re-)execute j-transaction
        ValidTo.setMin(j) 
```


The last step consists of two important improvements.

The first is an extremely simple dependency tracking (no graphs or partial orders) that considerably reduces aborts. When a j-transaction aborts, the write-set of its latest invocation is marked ABORTED. Since MVCC already supported the ABORTED mark, a higher-index k-transaction reading from a location in this write-set will delay until the j-transaction completes re-executing.

The second one increases re-validation parallelism. When a transaction aborts, rather than waiting for it to complete re-execution, it decreases ValidTo immediately; then if the re-execution writes to a (new) location which is not marked ABORTED, ValidTo is decreased again when the re-execution completes. 

The final scheduling algorithm, S-4, is captured abstractly in full in under one page as follows:


## **S-4:**


```
    DoneTo.initialize(0) 
    ValidTo.initialize(0) 

    Per thread main loop:


    If DoneTo >= n, ValidTo >= n, and no task is still running, exit loop
    needExecution := false

    If ValidTo < DoneTo 				# validate
        j := ValidTo.increment() ; if j > n, go back to loop
        re-read j-transaction read-set 
        If read-set differs from original read-set of the latest j-transaction execution 
        	Mark the j-transaction write-set ABORTED
            ValidTo.setMin(j)
        	needExecution := true

    Otherwise if DoneTo < n 			# execute
        j := DoneTo.increment() ; if j > n, go back to loop
            needExecution := true

    if needExecution
        (re-)execute j-transaction
        If the j-transaction write-set contains locations not marked ABORTED
            ValidTo.setMmin(j) 
```


S-4 lets re-validations of k-transactions, k > j,  proceed early while preserving SAFETY(j, k): if a k-transaction validation reads an ABORTED value, it has to wait; and if it reads a value which is not marked ABORTED and the j re-execution overwrites it, the k-transaction will be forced to revalidate again.

S-4 enables essentially unbounded parallelism. It reflects more-or-less accurately the [Block-STM](https://arxiv.org/pdf/2203.06871.pdf) approach; for details, see the paper (note, the description above uses different names from the paper, e.g., ABORTED replaces “ESTIMATE”, DoneTo replaces “execution_idx”, ValidTo replaces “validation_idx”). Block-STM has been implemented within the Diem blockchain core ([https://diem/diem](https://diem/diem)) and evaluated on synthetic transaction workload, yielding over 17x speedup on 32 cores under low/modest contention. 

