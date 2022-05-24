## Away Monolithic BFT Consensus, enter DAG Transport BFT Consensus

To scale the BFT (Byzantine Fault Tolerant) Consensus core of blockchains,
prevailing wisdom is to separate between two responsibilities. 

* The first is reliable DAG Trans for spreading yet-uncomfirmed transactions.
It regulates communication and optimizes throughput, but it tracks only causal ordering in the form of a DAG (Direct Acyclic Graph).

* The second is forming a sequential ordering of transactions and determining their commit finality. 
To do this, it must solve BFT Consensus utilizing the DAG.

It is funny how the community made a full circle, from early distributed consensus systems 
to where we are today. 
I earned my PhD more than two decades ago for contributions to scaling reliable distributed systems, 
Guided by, and collbrating with, pioneers in the field, including
@Ken Birman, @Danny Dolev, @Rick Schlichting, @Michael Melliar-Smith, @Louis Moser, @Robbert van Rennesse, @Yair Amir, @Idit Keidar.
The distributed middleware systems  of that time, e.g., Isis, Psync, Trans, Total and Transis, were designed for high-throughput
by building consensus over causal message ordering (!).

Recent interest in scaling blockchains is rekindling interest in this approach, but with emphasis on Byzantine fault tolerance, e.g., in systems like 
[HashGraph](https://hedera.com/hh_whitepaper_v2.1-20200815.pdf),
[Narwal](),
[DAG-rider](),
[Bullshark](https://arxiv.org/abs/2201.05677"), and
[Sui](). 

In this post, I will first explain the notion of **DAG Trans**, a reliable, causal broadcast transport that shares a DAG among parties.
I will then demonstrate the utility of DAG Trans through **Fin**, an extremely simple, one-phase BFT Consensus for the partial synchrony model. 
I will finish with a note on emerging **DAG Trans riding** BFT Consensus solutions. 

The advant of DAG Trans is that parties can spread messages carrying useful payloads (e.g., transactions), even when other parts of the system are stalled. 
DAG Trans injects into messages references to previous messages and regulates transmissions to saturate network capacity. 
In this post, we concentrate on a layer-by-layer regime, where each message must refer to a certain number of messages in the preceding layer, as depicted below.
There is no question that software modularity is advantageous, since
it removes the Consensus protocol from the critical path of communication. 
That said, most solutions do not rely on DAG Trans in a pure black-box manner.  

For example, randomized consensus protocols, e.g., DAG-rider and Tusk, inject into the DAG coin-tosses from the consensus protocol. 
Protocols for the partial synchrony model, e.g., Bullshark, delay message transmissions by the transport according to consensus protocol round timers, 
in order to ensure progress during periods of synchrony. 
The randomized Consensus protocol described in the original Hashgraph whitepaper does use the DAG in a pure manner, but it is too slow. 
Real life Hashgraph deployments must inject coin tosses to advance quickly during periods of asynchrony, 
(Say something about the pioneering work in Total? ToTo?)

In other words, rarely is the case that [all you need is a DAG](https://arxiv.org/abs/2102.08325).

To achieve consensus over the DAG Trans, Fin requires only a single API, `setInfo(v)`. 
Messages emitted by the DAG Trans should carry the value `v` in the latest `setInfo(v)` invokation. 
The value `v` is opaque to the DAG Trans and presumably of interest to the Consensus protocol.

The main takeaway from Fin is that by separating reliable transaction dissemination from Consensus, BFT Consensus based on DAG Trans can be made simple and highly performant at the same time.

## DAG Trans: Reliable Causal Broadcast 

<center>

<img src="/images/FIN/basic-DAG.png" width="500"  class="center"  />

  Figure 1: _A layer-by-layer causality DAG. Each message refers to 2F+1 ones in the preceding layer._

</center>

DAG Trans is a reliable, causal broadcast communication substrate for disseminating transactions among N=3F+1 parties.
It exposes three basic API's, `broadcast()`, `deliver()`, and `setInfo()`. 
The basic requirements of reliable broadcast are **Reliability**, **Agreement**, **Validity** and **Integrity**. 
A **Causality** requirement is added that exposes message dependencies. 

More specificially, DAG Trans provides a `broadcast(payload)` API for a party `p` to send a message to other parties.
A party's upcall `deliver(m)` is triggered when a message `m` can be delivered. 
To prepare for Consensus decisions, DAG Trans exposes a single additional API `setInfo(meta)`. 
A message broadcast by a party carries the latest `meta` value invoked in `setInfo(meta)` by the party. 

Messages are delivered carrying a sender's payload and additional meta information that can be inspected upon reception.
Every delivered message `m` carries the following fields:

- `m.sender`, the sender identity 
- `m.index`, a delivery index from the sender
- `m.payload`, contents such as transaction(s)
- `m.predecessors`, references to the last message its sender has seen from each party, including itself, in the past. In a layer-by-layer construction, it includes references to 2F+1 messages in the preceding layer.
- `m.info`, a meta information field reserved for the Consensus protocol at sender to inject through `setInfo()`

DAG Trans satisfies the following requirements:

* **Reliability.** 
If a `deliver(m)` event happens at an honest party, then eventually `deliver(m)` happens at every other honest party.

* **Agreement.**
If a `deliver(m)` happens at an honest party, 
and `deliver(m')` happens at another honest party, such that 
`m.sender = m'.sender`, 
`m.index = m'.index`
then `m = m'`.

* **Validity.**
If an honest party invokes `broadcast(payload)` then a `deliver(m)` with `m.payload = payload` event eventually happens at all honest parties.

* **Integrity.**
If a `deliver(m)` event happens at an honest party, then `p` indeed invoked `broadcast(payload)` where `m.payload = payload` 
and the latest `setInfo(meta)` by `p` has `m.info = meta`.

* **Causality.** 
If a `deliver(m)` happens at an honest party, 
then `deliver(d)` events already happened at the party for all messages `d` referenced in `m.predecessors`. 
Note that by transitively, this ensures its entire causal history has been delivered.

There is a very efective way to spread msgs reliably while incorporating causality information.
Message digests are echoed by all parties. When 2F+1 echoes are collected, a message can be delivered. 
The details of the echo protocol implementation are omitted here. We remark that echo protocols can be streamlined in an extremely effective manner, resulting in high utilization and throughout (see [Narwal](..)).
For Reliability to be satisfied, sufficiently many copies of `m` must be persisted prior to delivery by any honest party, to guarantee availability against a threshold F of failures. 

Reliable, causal transaction dissemination can be made highly efficient due to several considerations.

* A message dissemination substrate which is designed outside the consensus critical path

* A layer by layer construction allows the transport to advance at the speed of the fastest 2F+1 active parties with no centralized bottlenecks and with regular, balanced network utilization. There is no need to buffer or retransmit messages farther back than the current layer.

* A DAG can continue growing even when consensus is temporarily blocked from progress, e.g., when a consensus leader is faulty.

* A gossip transport may continue improving independently of any particular consensus protocol for
which is set up. A good modular design ensure that the transport evolution does not risk the (subtle) logic of BFT consensus built on top of it.



## Fin: BFT Consensus Using Trans DAG 

**Fin** is a simple BFT protocol built uding Trans DAG. 
Fin is based on PBFT but leveraging Trans DAG, has a one-phase commit rule and an extremely simple leader protocol.
The name Fin, a small part of a shark's tail, stands for the protocol succinctness. 

The Fin protocol works in a view-by-view manner. View numbers are embedded in DAG messages using the `setInfo()` API. We refer to a message `m` as a _"view-r message"_ if it carries a meta-information field `m.info = r`.
Note, protocol views do *NOT* correspond to DAG layers, but rather, view numbers are explicitly embedded in the meta-information field of messages.

There is a pre-designated leader for view `r`, denoted `leader(r)`, which is known to everyone.
At each party `p`, the protocol for view `r` works as follows:

1. **Entering a view.** 
Upon entering view `r`, party `p` starts a view timer set to expire after a pre-determined view delay. 

2. **Proposing.** 
The leader `leader(r)` of view `r` waits to deliver 2F+1 view-(r-1) messages or 2F+1 view-(-(r-1)) messages, and then invokes `setInfo(r)`. 
    * Thereafter, the next transmission by the leader will carry the new view number as indication of _proposing_ in view `r`.

3. **Voting.**
Each party `p` other than the leader waits to deliver the first view-r message from `leader(r)` and then invokes `setInfo(r)`. 
    * Thereafter, the next transmission by `p` will carry the new view number as indication of _voting_ for the view-r proposal.

4. **Committing.** 
A commit of a leader proposal at view `r` with its causal predecessors happens if the DAG maintains the following conditions:

    * A first view-r message from `leader(r)`, denoted `proposal(r)`, exists. 
    * `proposal(r).predecessors` refers to either 2F+1 view-(r-1) messages or 2F+1 view-(-(r-1)) messages (or r=1).
    * First view-r messages from 2F+1 parties `p` exist, each having `predecessors` referring to `proposal(r)`. 

Upon a commit of `proposal(r)`, a party disarms the view-r timer.  

5. **Expiring the view timer.**
If the view-r timer expires, a party invokes `setInfo(-r)`. 
    * Thereafter, the next transmission by `p` will carry the negative view number as indication of _expiration_ of `r`.

7. **Advancing to next view.**
A party enters view `r+1` if the DAG satisfies one of the following two conditions:
    * A commit of `proposal(r)` happens.
    * View-(-r) messages indicating view-r expiration from 2F+1 parties exist.

It is worthwhile noting that, at no time is transaction broadcast slowed down by the Fin protocol. Rather, Consensus logic is embedded into the DAG structure simply by injecting view numbers into it.

The reliability and causality properties of DAG Trans makes arguing about correctness very easy, 
though a formal proof of correctness is beyond the scope of this post. 
Briefly, the **safety** of commits is as follows. If ever a view-r proposal `proposal(r)` becomes committed, 
then it is in the causal past of 2F+1 parties that voted for it.
Any future view proposal must refer directly or indirectly to 2F+1 view-r messages, of which F+1 are votes for `proposal(r)`.
Hence, any commit of a future view causally follows (hence, transitively re-commits) `proposal(r)`. 

The protocol **liveness** during periods of synchrony stems from two key mechanisms. 

First, after GST (Global Stabilization Time), 
i.e., after communication has become synchronous,
views are inherently synchronized through DAG Trans. 
For let $\Delta$ be an upper bound on communication after GST.
Once a view `r` with an honest leader is entered by the first honest party, within $2 * \Delta$, both the leader and all honest parties enter view `r` as well. 
Within $4 * \Delta$, the view-r proposal and votes from all honest partes are spread to everyone. 



Second, a future view cannot preempt the current view commit. To start a new view, 
a leader must collect either 2F+1 view-r _votes_ for the leader proposal, hence commit it; or 2F+1 view-(-r) _expirations_, which is impossible. 

Fin is modeled after PBFT while removing the complexity of PBFT's view-change, thus supporting regular leader rotation.
PBFT works in two-phases. The first phase protects against leader equivocation. Building over a causal DAG Trans, non-equivocation is already guaranteed at the transport level. 
The second phase guards commits by locking votes that transfer to the next view. 
This is the most subtle ingredient of PBFT. In particular, a new leader proposal must carry a proof of safety composed of 2F+1 
messages attesting to the highest vote from previous views. 
In Fin, a leader proposal simply references those 2F+1 messages from the previous view.

## Pure-DAG Solutions

In a pure DAG-rider solution, parties passively analyze the DAG structure and autonomously arrive at commit ordering decisions. 
No extra messages are exchanged by the consensus protocol nor is it given an opportunity to inject information into the DAG or control message emission. 
Total and Hashgraph's whitepaper algorithm are pure DAG-rider solutions. Both use randomization to solve consensus and both are rather theoretical and may suffer prohibitive latencies.


