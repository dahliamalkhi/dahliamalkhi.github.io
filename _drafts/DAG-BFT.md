## Away monolithic BFT consensus systems, enter DAG-based BFT consensus

To scale the BFT (Byzantine Fault Tolerant) Consensus core of blockchains,
prevailing wisdom is to separate between two responsibilities. 

* The first is reliable Transport for spreading yet-uncomfirmed transactions.
It regulates communication and optimizes throughput, but it tracks only causal ordering in the form of a DAG (Direct Acyclic Graph).

* The second is forming a sequential ordering of transactions and determining their commit finality. 
To do this, it must solve BFT Consensus utilizing the DAG.

It is funny how the community made a full circle, from early distributed consensus systems 
to where we are today. 
I earned my PhD more than two decades ago for contributions to scaling reliable distributed systems. 
Guided by and collbrating with the pioneers, e.g., 
@Ken Birman, @Danny Dolev, @Rick Schlichting, @Michael Melliar-Smith, @Louis Moser, @Robbert van Rennesse, @Yair Amir, @Idit Keidar, 
distributed middleware systems like Isis, Psync, Trans, Total and Transis, were designed for high-throughput
by building consensus over causal message ordering.

Recent interest in scaling blockchains is rekindling interest in this approach carrying with emphasis on Byzantine fault tolerance, e.g., in systems like 
[HashGraph](https://hedera.com/hh_whitepaper_v2.1-20200815.pdf),
[Narwal](),
[DAG-rider](),
[Bullshark](https://arxiv.org/abs/2201.05677"), and
[Sui](). 

In this post, I will first explain the notion of a reliable, causal broadcast Transport.
I will then demonstrate an extremely simple, one-round BFT Consensus using the causal Transport that I will name Fin. 
To do this, Fin only requires that the Transport exposes an API `setInfo(v)`, 
embedding a value v (presumably of interest to the Consensus protocol) inside future transmissions.

I will finish with a note on emerging DAG-riding solutions. 
There is no question that software modularity is advantageous, though
most of these solutions do not rely on a DAG in a black-box manner. 
For example, randomized consensus protocols like DAG-rider and Tusk inject into the DAG coin-tosses from the consensus protocol. 
Protocols like Bullshark control message emissions according the consensus protocol round timers in order to ensure progress during periods of synchrony. 
In other words, rarely is the case that [all you need is a DAG](https://arxiv.org/abs/2102.08325).
Like Bullshark, Fin is not a black-box solution, it controls message emissions according to round timers.

Pure DAG BFT Consensus solutions exists, that extract consensus passively and autonomously solely based on the DAG structure, with no extra information exchanged.

==> Main takeaway: By separating the task of reliably disseminating transactions, DAG-based BFT consensus can be made simple and highly performant.

## Reliable, Causal Broadcast Transport 

<center>

<img src="/images/Fin/basic-DAG.png" width="500"  class="center"  />

  Figure 1: _A layer-by-layer causality DAG. Each node refers to 2F+1 ones in the preceding layer._

</center>

A reliable, causal broadcast Transport is a communication substrate for disseminating transactions among N=3F+1 parties.
A Transport exposes a `broadcast(payload)` API for a party to send a message to other parties.
A party's upcall `deliver(m)` is triggered when a message `m` can be delivered.

The basic reliability requirements of reliable broadcast are Reliability, Agreement, Validity and Integrity, as follows:

* **Reliability.** 
If an honest party delivers a message `m`, then eventually every other honest party delivers `m`.
For Reliability to be satisfied, sufficiently many copies of `m` must be persisted prior to delivery by any honest party, to guarantee availability against a threshold F of failures. 

* **Agreement.**
If an honest party delivers a message `m` as the _k'th_ message from `p`,
and another honest party delivers a message `m'` as the _k'th_ message from `p`,
then `m = m'`.

* **Validity.**
A message sent by an honest party is eventually delivered by all honest parties.

* ** Integrity.**
If an honest party delivers a message `m` from an honest party `p`, then `p` indeed invoked `broadcast(m)`.

To serve as a transport for BFT Consensus, two additional mechanisms are added. 

* **Meta-information field.**
To prepare for Consensus decisions, the Transport exposes a additional
API `setInfo(meta)`. Every broadcast message carries the latest `meta` value invoked in `setInfo(meta)`. 
Both `payload` and `meta` are opaque for the Transport.

* **Causal dependencies.**
Every message carries references to the last message its sender has seen from each party, including itself, in the past. 
For simplicity, this post will restrict the discussion to a layer-by-layer DAG Transport, in which each message except the first layer carries references to at least 2F+1 messages in the preceding layer.

Every delivered message carries the following Fields:

- `info`, a meta information field reserved for the Consensus protocol at sender to inject
- `payload`, contents such as transaction(s)
- `predecessors`, references to 2F+1 messages in the preceding layer

The requirement from a causal Transport is as follows:

* **Causality.** 
If an honest party delivers a message then all messages referenced in `predecessors` have been delivered. Note that transitively, this ensures
its entire causal history has been delivered.

There is a very efective way to spread msgs reliably while incorporating causality information.
Message digests are echoed by all parties. When 2F+1 echoes are collected, a message can be delivered. 
The details of the echo protocol implementation are omitted here. We remark that echo protocols can be streamlined in an extremely effective manner, resulting in high utilization and throughout (see [Narwal](..)).

Such as reliable, causal transaction dissemination 
can be made highly efficient due to several considerations.

* A message dissemination substrate which is designed outside the consensus critical path

* A layer by layer construction allows the transport to advance at the speed of the fastest 2F+1 active parties with no centralized bottlenecks and with regular, balanced network utilization. There is no need to buffer or retransmit messages farther back than the current layer.

* A DAG can continue growing even when consensus is temporarily blocked from progress, e.g., when a consensus leader is faulty.

* A gossip transport may continue improving independently of any particular consensus protocol for
which is set up. A good modular design ensure that the transport evolution does not risk the (subtle) logic of BFT consensus built on top of it.



## BFT consensus inside the DAG 

Here, we describe an extremely simple in-DAG protocol which is based on PBFT, that has one round commit rule.
We call it Fin, a small part of a shark's tail.

The Fin protocol works in a view-by-view manner. View numbers are embedded in DAG messages using the `setMeta()` API. We refer to a message `m` as a _view-r message_ if it carries a meta-information field `m.meta = r`.
Note, Protocol views do *NOT* correspond to DAG layers, but rather, view numbers are explicitly embedded in the meta-information field of messages.

There is a pre-designated leader for view `r` known to everyone, we will denote it by `leader(r)`.
At each party `p`, the view `r` protocol works as follows:

1. **Entering a view.** 
Upon entering view `r`, party `p` starts a view timer set to expire after a pre-determined view delay RT. 

2. **Proposing.** 
The leader `leader(r)` of view `r` waits to deliver 2F+1 view-(r-1) messages or 2F+1 view-(-(r-1)) messages, and then invokes `setMeta(r)`. 
  * Thereafter, a transmission by the leader will carry the new view number as indication of _proposing_.

3. **Voting.**
Each party `p` other than the leader waits to deliver the first view-r message from `leader(r)` and then invokes `setMeta(r)`. 
  * Thereafter, a transmission by `p` will carry the new view number as indication of _voting_.

4. **Committing.** 
A commit of a leader proposal at view `r` with its causal past happens if the DAG maintains the following conditions:
  * A first view-r message from `leader(r)`, denoted `proposal(r)`, exists. 
  * `proposal(r).predecessors` refers to either 2F+1 view-(r-1) messages or 2F+1 view-(-(r-1)) messages (or r=1).
  * First view-r messages from 2F+1 parties `p`, each has `predecessors` referring to `proposal(r)`, exist. 

5. **Expiring the view timer.**
Upon a commit of `proposal(r)` a party disarms the view-r timer.  If the view-r timer expires, a party invokes `setMeta(-r)`. 
  * Thereafter, a transmission by `p` will carry the new view number as indication of _expiration_.

7. **Advancing to next view.**
A party enters view `r+1` if the DAG satisfies one condition of the following two:
  * A commit of `proposal(r)' happens.
  * View-(-r) messages indicating expirations from 2F+1 parties exist.

It is worthwhile noting that, at no time are transaction broadcast slowed down by the Fin protocol. Rather, Consensus logic is embedded into the DAG structure simply by injecting view numbers into it.

The Causal, Reliable Transport makes arguing about correctness very easy, 
though a formal proof of correctness is beyond the scope of this post. 
Briefly, the **safety** of commits is as follows. If ever a view-r proposal becomes committed, 
then it is in the causal past of 2F+1 parties that voted for it.
Any future view proposal must refer directly or indirectly to 2F+1 view-r messages, of which F+1 are votes for the committed proposal.
Hence, any commit of a future view causally follows and transitively commits the view-r proposal. 

The protocol **liveness** stems from two key mechanisms. First, after GST, views are inherently synchronized through the Transport, since all message deliveries by honest parties are within 2*Delta delay of each other. 
Once a view `r` with an honest leader is entered by the first honest party, within 2*Delta, both the leader and all honest parties enter view `r` as well. 
Within 4*Delta, the view-r proposal and votes from all honest partes are spread to everyone. 
Second, a future view cannot preempt the current view commit. To start a new view, 
a leader must collect either 2F+1 view-r _votes_ for the leader proposal, hence commit it; or 2F+1 view-(-r) _expirations_, which is impossible. 

Fin is modeled after PBFT while removing the complexity of PBFT's view-change, thus supporting regular leader rotation.
PBFT works in two-phases. The first phase protects against leader equivocation. Building over a causal Transport, non-equivocation is already guaranteed at the transport level. 
The second phase guards commits by locking votes that transfer to the next view. 
This is the most subtle ingredient of PBFT. In particular, a new leader proposal must carry a proof of safety composed of 2F+1 
messages attesting to the highest vote from previous views. 
In Fin, a leader proposal simply references those 2F+1 messages from the previous view.

## Pure-DAG Solutions

In a pure DAG-rider solution, parties passively analyze the DAG structure and autonomously arrive at commit ordering decisions. 
No extra messages are exchanged by the consensus protocol nor is it given an opportunity to inject information into the DAG or control message emission. 
Total and Hashgraph's whitepaper algorithm are pure DAG-rider solutions. Both use randomization to solve consensus and both are rather theoretical and may suffer prohibitive latencies.


