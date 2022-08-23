---
title: 'Execution and Parallelism for DAG-based BFT Consensus'
date: 2022-08-23 00:00:00 -07:00
permalink: "/posts/2022/08/dag-exec/"
tags:
- Blockchain
- DAG
- Transaction Execution
header:
  teaser: "/images/DAG/caveman-pushing-cart.png"
  overlay_image: "/images/DAG/caveman-pushing-cart.png"
  overlay_filter:  0.5
  caption: "image licensed from iStock"
excerpt: Paradigms for high-throughput **transaction execution** over a DAG, meeting recent advances in scaling core Consensus ordering protocols in blockchains.
category:
- tutorial
---

Authors: George Danezis and Dahlia Malkhi

In DAG-based BFT Consensus (the subject of two previous blog posts, ["On BFT Consensus Evolution: From Monolithic to DAG"](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/), and "[Another Advantage of DAG-based BFT: BEV Resistance](https://dahliamalkhi.github.io/posts/2022/07/dag-fo/)"), multiple block proposals are sent in parallel by all Validators and it may not be clear how and when to process transactions they contain and certify the outcome.

It's time to talk about transaction execution for DAG-based Consensus protocols.

## Background: DAG-based Ordering
------------------------------

In a DAG-based BFT Consensus protocol, every consensus message has direct utility towards forming a total ordering of committed transactions. More specifically, each Validator participating in DAG Consensus independently packs yet-unconfirmed transactions or their digests into a block, adds references to previously delivered (defined below) messages, and broadcasts a message carrying the block and the causal references to all Validators.  Blocks are reliably delivered and the references they carry become the backbone of a causally ordered directed acyclic graph (DAG) structure.  Then, Validators interpret their DAG  locally, without exchanging more messages, and determine a view by view total ordering of accumulated transactions.

In each view, a common set of blocks across Validators is committed or potentially committed. Each block in the set contains a set of transactions. A sequence can be extracted from this set of blocks by filtering out any already sequenced transactions (duplicates and re-submissions), ordering the transactions causally using protocol specific sequence numbers or accounts, using a topological sort, and then finalising the sequence using some tie breaking rule for non-causally constrained transactions, such as giving priority to transactions with a higher gas fee, or other considerations like [MEV Protection on a DAG](https://arxiv.org/pdf/2208.00940.pdf). While many variants of the above can be devised, a commit or potential commit results in a sequence of transactions. To distinguish the set of transactions in a view from those in blocks, we refer to them as the View-set (of transactions).

The question is when and by whom should View-set transactions be processed, and where and how should the result be published?

## DAG Execution Approaches
------------------------

#### Option #1: post-ordering off-DAG

In this option, the DAG only orders transactions as suggested above. All observers -- including Validators and clients -- process them outside the DAG protocol. Every observer needs to process all the transactions in the current committed prefix in order to arrive at a state resulting from processing the entire committed prefix. Observers can process the chain incrementally, as new view-sets become committed.

This approach is simple, and in-line with the currently popular ideas around building blockchain in a modular fashion, combining different subsystems for availability, sequencing and execution. In that context the DAG Consensus just does sequencing (and maybe some availability) but relies on other layers for execution. The downside of this approach is that it does not provide - by default - a certificate on executed state to support light clients co-signed by the DAG Consensus Validators. As a result, additional security assumptions need to be made on the execution layer to ensure the security of the whole system.

#### Option #2: post-ordering checkpoint on-DAG

In this option, when Validators observe commits, they "lazily" and asynchronously (i.e., with no concrete protocol-step or time bound) construct and execute the sequence of transactions, and then post a signed commitment of its result in a DAG block or as a transaction sequenced in the Consensus. Clients (in particular light ones) may wait for F+1 state commitments (where F is the maximum number of byzantine validators) to be posted to the DAG and rely on these to authenticate reads, instead of processing transactions themselves.

Performing the execution asynchronously is simple and is outside the critical path of ordering. Compared with the previous approach, it results in a collectively signed state checkpoint, containing sufficient information to support light clients. On the downside, asynchrony requires light clients to wait, potentially for a long and unknown amount of time until they may authenticate reads. This delay may be longer and longer if execution is the bottleneck of the system; and could block light clients from being able to construct new transactions to process.

#### Option #3: leader-proposed execution

This option can work with DAG-based BFT Consensus protocols for the partial-synchrony model like (the first part of) [Bullshark](https://arxiv.org/abs/2201.05677%22) and [Fin](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/). It may also work for [Tusk](https://arxiv.org/abs/2105.11827) but is potentially inefficient. It works as follows.

When a leader Consensus proposal is embedded in a DAG, the leader already knows what is included in a proposal (namely, the causal history of the proposal). Therefore, despite all the block proposals going on in parallel, the leader can preprocess the outcome of executing the sequence on the basis of the proposed block and bring it to a vote. The leader includes the proposed outcome as a state commitment, and when Validators vote, they check and implicitly vote for the outcome as well.

A leader-proposed execution approach works well in Fin, but in Tusk and in (full) Bullshark, the leader is determined after the fact: so to make this work all block proposers would have to propose a state commitment, and all votes should pre-execute the proposals -- despite the fact that only one will be selected. This is correct but computationally inefficient, at least in this naive form.

The benefit of the approach is allowing a state commitment to be observed at exactly the same time as the block is certified and as the DAG is being constructed. Light-clients can use them immediately. It also allows the DAG construction to feel backpressure from the delays in execution, in case execution is a bottleneck, keeping the two subsystems in tune with each other. The latter point is also its downside: taking turns devoting resources between ordering (a network bound activity) and execution (a CPU / storage bound activity) may lead to resource underutilization for both, and a less efficient system overall.

It is worth pointing to another variant of this approach: in an x-delayed leader-proposed execution, for some value x,  the leader of view k+x posts the output of view k, included in its proposal for k+x. A Validator's vote on a leader k+x proposal is a fortiori a vote for the outcome of view k. 

## Parallel Execution
------------------

No matter who and when executes blocks (per the discussion above), there are ways to accelerate the execution by parallelizing work. This is crucial for high throughput: unless execution can meet ordering throughput, a backlog of committed transactions might be formed whose committed state is unknown, which may cause clients to delay observing the committed state and not be able to produce new transactions.

At a high level, there are two key approaches for accelerating execution through parallel work:

1.  Exploit the inherent concurrency among transactions to speed up processing through parallelism. Parallel execution can utilise available multi-core compute resources and may result in significant performance improvement over sequential processing. 

2.  Prepare transactions for faster validation through various preprocessing strategies, harnessing the collective compute power of Validators or external helpers for preparation tasks.

We focus the discussion on accelerating execution of a single view. Recall that in a view, a common set of blocks across Validators is committed, each block containing a set of transactions. A sequence ordering is extracted over the View-set of transactions consisting of the transactions in all the committed blocks. 

#### Parallel Option #1: post-ordering acceleration via parallel-processing

In this option, the goal is to process an ordered View-set of transactions as if it was executed sequentially and arrive at the sequential result. However, rather than executing transactions one after another, the key idea is that some transactions may not be conflicting, namely, they do not read or write any common data items. Therefore, they can be processed in parallel, enabling execution acceleration that arrives at the correct sequential result. Another performance boost may be derived by combining the outputs of transactions into a batched-write.

Post-ordering acceleration of transaction processing is the topic of a previous post, ["Block-STM: Accelerating Smart-Contract Processing"](https://dahliamalkhi.github.io/posts/2022/04/block-stm/). Rather than applying Block-STM on blocks, we can employ it on ordered View-sets. Each Validator uses Block-STM independently to parallel-process a leader proposal.  

#### Parallel Option #2: concurrency hints

Borrowing from the pioneering work on ["Adding Concurrency to Smart Contracts"](https://arxiv.org/pdf/1702.04467.pdf), we can add to Parallel Option #1 various ways in which Validators help each other by sharing hints about concurrency.

Hints may be produced in a preprocessing phase, where each Validator provisionally processes and/or statically analyses transactions in its own block. For each transaction, it generates a provisional read-set and write-set and records the sets to guide  parallel execution and embeds them inside block proposals. The information about transaction dependencies can seed parallel execution engines like Block-STM (and others) and help reduce abort rates.

An important aspect of this regime is that Validators can preprocess blocks in parallel, in some cases simultaneously with collecting transactions into blocks and posting them to the DAG. The time spent on preprocessing in this case overlaps the (networking intensive) ordering phase and hence, it may result in very good utilisation of available compute resources.

A different regime is for one (or several) Validators to go through a trial-and-error speculative transaction processing, and then share a transcript of the concurrent schedule they "discovered" with others. We can appoint Validators to discover concurrency on a rotation basis, where in each view some Validators shift resources to execution and other Validators re-execute the parallel schedule deterministically but concurrently, saving them both work and time. Alternatively, we can simply let fast Validators help stragglers catch up by sharing the concurrency they discovered.  

#### Other accelerators and future research

Recent advances in ZK rollups allow to offload compute and storage resources from Validators (for an excellent overview, see ["An Incomplete Guide to Rollups", Vitalik, 2021](https://vitalik.ca/general/2021/01/05/rollup.html)). These methods allow a powerful entity, referred to as "Prover", to execute transactions and generate a succinct proof of committed state, whose verification is very fast. Importantly, only one Prover needs to execute transactions because the Prover need not be trusted; the proof is self-verifying that correct processing was applied to produce the committed state. Therefore, the Prover can run on dedicated, beefy hardware. The work needed by Validators to verify such proofs is significantly reduced relative to fully processing transactions.

Generally, ZK proof generation is slow, currently slower than processing transactions, and the main use of ZK is not accelerating but rather, compressing state and offloading computation from Validators. However, specific rollups could potentially be used for acceleration. For example, a recent method for ["Aggregating and thresholdizing hash-based signatures using STARKs"](https://eprint.iacr.org/2021/1048.pdf) could be applied to reduce the compute load incurred by signature verification on sets of transactions.

Another possible acceleration can come from splitting execution to avoid repeating executing each transaction by every Validator. This approach presents a shift in the trust model, because it requires trusting subsets of Validators with execution results, or to delegate execution to dedicated trusted executors (as in, e.g., [[Hyperledger Fabric]](https://arxiv.org/abs/1801.10228) and [[ParBlockchain]](https://arxiv.org/pdf/1902.01457.pdf)).

Splitting execution across subsets may be based on account ownership, where actions on behalf of each account are processed on its dedicated executors. In networks like Sui and Solana, transactions are annotated with the objects or accounts they access respectively so that splitting execution in this manner is easier. The advantage of object or account centric computation is that parallel processing does not generate conflicts, but programming in this model has to be adapted and constrained to fully take advantage of this opportunity for parallelism.

Another approach is to create a dependency graph among transactions based on preprocessing or static analysis. We can then use the graph to split transactions into parallel "buckets" that can be processed in parallel. This strategy is used in many academic works, a small sample of which that specifically focus on pre-ordered batching includes:

-   ["Rethinking serializable multiversion concurrency control", by Faleiro et al., 2015](https://arxiv.org/pdf/1412.2324.pdf)

-   ["Adding Concurrency to Smart Contracts", by Dickerson et al., 2017](https://arxiv.org/abs/1702.04467)

-   ["Improving Optimistic Concurrency Control Through Transaction Batching and Operation Reordering", by Ding et al., 2018](http://www.vldb.org/pvldb/vol12/p169-ding.pdf)

-   ["ParBlockchain: Leveraging Transaction Parallelism in Permissioned Blockchain Systems", by Amiri et al., 2019"](https://arxiv.org/pdf/1902.01457.pdf) 

-   ["OptSmart: A Space Efficient Optimistic Concurrent Execution of Smart Contracts", by Anjana et al., 2021](https://arxiv.org/abs/2102.04875)

## Summary
-------

A long lasting quest for scaling the core consensus engine in blockchains brought significant advances in Consensus ordering algorithms, culminating in a recent wave of DAG-based BFT ordering protocols. However, to support high-throughput, we need to enable high-throughput transaction processing that meets ordering speeds. This post presents several paradigms for transaction execution over DAG-based Consensus and lays out approaches for accelerating transaction processing through parallelism.
