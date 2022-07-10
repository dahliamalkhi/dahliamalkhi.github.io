---
title: 'HotStuff: Three-Chain Rules!'
date: 2019-08-01 00:00:00 -07:00
permalink: "/posts/2019/08/hotstuff-three-chain-rules/"
tags:
- BFT
- consensus
- hotstuff
---

_Renewed interest in the Blockchain world on a long standing problem of asynchronous Byzantine Fault Tolerant (BFT) Consensus focuses on the following scaling challenges:_

-   _**Chain Quality**  necessitates fast/frequent proposer rotation for fairness and liveness_
-   _**Linearity**_ _means paying a communication cost that amounts to sending a proposal over the network once to everyone. This cost is kept against a broad range of network conditions, and includes proposer rotation._
-   _**Responsiveness** implies that the protocol can progress at network speed, i.e., as soon as messages from a quorum are collected, without waiting some a priori upper bound on network delay._

_These three properties are needed to maintain safety and high performance against a broad range of network conditions, including frequent proposer rotation._

#### Enter HotStuff!

_[HotStuff](https://arxiv.org/abs/1803.05069)  is the first BFT Consensus that meets all three goals._

_HotStuff further embodies a minimalist algorithmic framework that bridges between classical BFT solutions and the blockchain world; the entire protocol is captured in less than half a page of pseudo-code (Figure 3 on page 6)!_

----------

### The need for new BFT solutions

Even on “a good day” when the system behaves synchronously (without which, solving BFT Consensus is impossible), existing solutions do not meet one or more of the above targets.

Most protocols contain  _quadratic_ voting steps. When Byzantine consensus protocols were originally conceived, a typical target system size was _n=4_ or _n=7,_ tolerating one or two faults_._ But scaling  BFT consensus to _n=2000_ means that even on a good day_,_ when communication is timely and a handful of failures occurs, quadratic steps require 4,000,000 messages. A cascade of failures might bring the communication complexity to whopping 8,000,000,000 (!) transmissions for a single consensus decision.

No matter how good the engineering and how we tweak and batch the system, these theoretical measures are a roadblock for scalability.

Some protocols have linearity but rely on synchrony for safety. To guarantee safety, synchronous bounds over a wide Internet are set to multiple seconds or minutes.

We are therefore faced with a conundrum:

-   On the one hand, we love asynchronous BFT solutions (i) because they can progress at the speed of the communication network, whereas synchronous solutions advance at a pre-determined conservative rate, and (ii) because they always guarantee safety against a threshold of failures, even in face of asynchrony.
-   On the other hand, they are hard to scale.

![conundrum](/images/conundrum.png)

### [HotStuff](https://arxiv.org/abs/1803.05069)  in a Nutshell

[HotStuff](https://arxiv.org/abs/1803.05069)  is built around three ingredients that bridge between the classical BFT Consensus foundations and the blockchain world:  _Blocks_,  _Votes_, and  _Pacemakers_.

![branch](/images/branch.png)

**Blocks:**  To be considered in the protocol, proposals are encapsulated in _blocks_  that extend branches of a block-tree, rooted at a _genesis_ block. In the picture above, blocks are depicted as filled rectangles. Solid arrows connect children to parents, and the _height_ of a block is its distance from the root. Proposal values are indicated as B, B’, B”, W, W’, W”, etc.

When two blocks do not extend each other’s branch they are _conflicting._ Conflicting proposals may arise if two proposers simultaneously generate proposals, or if a bad proposer intentionally ignores the current tail of the chain and forks.

**Votes and QCs:**  Replicas cast  _votes_ on blocks. When _2f+1_  votes exist on a block they can form a  _Quorum Certificate (QC)._

A proposer always uses the highest QC it knows to choose which branch to extend. In the picture above, the QC justifications for blocks are depicted as dashed arrows to the block refered by the QC.

**Commit rule:** The decision when a block is considered  _committed_ rests purely on a simple graph structure, a  _three-chain,_ as depicted below_._ The head B of a three-chain has a QC(B) by a direct descendent B’; B’ has a QC(B’) by a direct descendet B”; and QC(B”) has has a QC.

![hs](/images/hs.png)

HotStuff (2018)

In order to guard safety, once a replica votes on the tail B” of a two-chain, it accepts a conflicting proposal only on a one-chain with a higher QC than QC(B’).

The three-chain commit rule provides the following guarantee. The first link in the chain guarantees 2f+1 votes on a unique block. The second link in the chain guarantees 2f+1 replicas have a QC on a unique block. The last link guarantees that 2f+1 replicas have the highest QC of any two-chain that has a vote.

**Pacemaker:** The details of electing a proposer are encapsulated in an abstraction call a  _pacemaker_, that needs to provide two guarantees: Infinitely often, all replicas spend a certain period of time jointly at a height, and a unique correct proposer is elected for the height.

A naive way to achieve the pacemaker properties is by doubling the time each replica spends at each height until a decision is made. At each height, proposers can be rotated deterministically, they made be elected via a distributed pseudo random function, or they user a randomized back-off protocol.

----------

### Other Protocols in the Lens of  [HotStuff](https://arxiv.org/abs/1803.05069)

It turns out that improvement does not necessitate complexity. The HotStuff framework simplifies protocol design, and provides a generic algorithmic foundation for other solutions.

The commit rules of four additional BFT Consensus protocols are depicted below in the HotStuff framework. All four protocols can be expressed as  _one-chain_  and  _two-chain_  variants of the HotStuff commit graph rule, the mechanisms for a proposer to collect QCs.

-   A one-chain commit rule is used in  [[DLS 1988]](https://dl.acm.org/citation.cfm?id=42283). Only the proposer can reach a commit decision via a one-chain.

![dls](/images/dls.png)

DLS (1988)

-   Two-chain commit rules are used in  [[PBFT 1999]](http://pmg.csail.mit.edu/papers/osdi99.pdf),  [[Tendermint 2016]](https://atrium.lib.uoguelph.ca/xmlui/handle/10214/9769)  and  [[Casper 2017]](http://arxiv.org/abs/1710.09437). They differ in their proposer mechanisms. PBFT justifies a proposer  **not** having a highest QC, Tendermint and Casper **wait** the maximal network delay for a proposer to collect the highest QC.
    
    ![pbft](/images/pbft.png)
    
    PBFT (1999)
    
    ![tndrmnt](/images/tndrmnt.png)
    
    Tendermint (2016)
    
    ![casper](/images/casper.png)
    
    Casper (2017)
