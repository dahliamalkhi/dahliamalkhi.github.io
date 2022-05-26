## Away with Monolithic BFT Consensus; Enter DAG Transport BFT Consensus

To scale the BFT (Byzantine Fault Tolerant) Consensus core of blockchains,
prevailing wisdom is to separate between two responsibilities. 

* The first is reliable DAG Trans for spreading yet-unconfirmed transactions.
It regulates communication and optimizes throughput, but it tracks only causal ordering in the form of a DAG (Direct Acyclic Graph).

* The second is forming a sequential ordering of transactions and determining their commit finality. 
To do this, it must solve BFT Consensus utilizing the DAG.

The advent of DAG Trans is that while solving BFT Consensus, parties spread messages that carry useful payloads (e.g., transactions). 
A BFT Consensus protocol can periodically commit batches from the DAG by merely referring to the leaves of the DAG. 
Moreover, parties can continue sending messages and the DAG keep growing even when Consensus is stalled. 
Eventually, when Consensus makes progress, it can commit the latest batch of accumulated messages from the DAG. 

It is funny how the community made a full circle, from early distributed consensus systems to where we are today. 
I earned my PhD more than two decades ago for contributions to scaling reliable distributed systems, 
Guided by and collaborating with pioneers in the field, including
@Ken Birman, 
@Danny Dolev, 
@Rick Schlichting, 
@Michael Melliar-Smith, 
@Louis Moser, 
@Robbert van Rennesse, 
@Yair Amir, 
@Idit Keidar.
Distributed middleware systems of that time, e.g., 
[Isis](https://dl.acm.org/doi/10.1145/37499.37515), 
[Psync](https://dl.acm.org/doi/10.1145/65000.65001), 
[Trans](https://ieeexplore.ieee.org/document/80121?tp=&signout=success), 
[Total](https://dl.acm.org/doi/10.1145/327164.327298)
and 
[Transis](https://dahliamalkhi.github.io/files/Transis-CACM1994.pdf), 
were designed for high-throughput by building consensus over causal message ordering (!).
Recent interest in scaling blockchains is rekindling interest in this approach with emphasis on Byzantine fault tolerance, e.g., in systems like 
[HashGraph](https://hedera.com/hh_whitepaper_v2.1-20200815.pdf),
[Narwhal](https://arxiv.org/abs/2105.11827),
[DAG-rider](https://arxiv.org/abs/2102.08325),
[Bullshark](https://arxiv.org/abs/2201.05677"), and
[Sui](https://medium.com/mysten-labs/announcing-narwhal-tusk-open-source-3721135abfc3). 

In this post, I will first explain the notion of **DAG Trans**, a reliable, causal broadcast transport that shares a DAG among parties.
I will then demonstrate the utility of DAG Trans through **Fin**, an extremely simple, one-phase BFT Consensus for the partial synchrony model. 
I will finish with a note on emerging **DAG Trans riding** BFT Consensus solutions. 

Fin is meant for demonstration purposes, not as a full-fledged BFT Consensus system design. The main takeaway from Fin is that **by separating reliable transaction dissemination from Consensus, BFT Consensus based on DAG Trans can be made simple and highly performant at the same time**.

## DAG Trans: Reliable Causal Broadcast 

  <img src="/images/FIN/basic-DAG.png" width="500"  class="center"  />

  **_Figure 1:_** _A layer-by-layer causality DAG. Each message refers to 2F+1 ones in the preceding layer._

DAG Trans is a reliable, causal broadcast communication substrate for disseminating transactions among N=3F+1 parties, at most F of which are presumed Byzantine faulty and the rest are honest.
The substrate exposes three basic API's, `broadcast()`, `deliver()`, and `setInfo()`. 
In a nutshell, DAG Trans guarantees that all parties deliver the same ordered sequence of messages by each sender and exposes a causal-ordering relationship among them. These properties are described below as **Reliability**, **Agreement**, **Validity**, **Integrity**, 
and **Causality**. 

More specifically, DAG Trans provides a `broadcast(payload)` API for a party `p` to send a message to other parties.
A party's upcall `deliver(m)` is triggered when a message `m` can be delivered. 

Each message must refer to a certain number of preceding messages.
In this post, we concentrate on a layer-by-layer regime, where in each layer, a messages refers 
to a certain number of messages in the preceding layer, as depicted in **Figure 1** above.
The layer-by-layer design regulates transmissions so as to saturate network capacity. 

To prepare for Consensus decisions, DAG Trans exposes a single additional API `setInfo(meta)`. 
When a party invokes `broadcast()`, the message carries the latest `meta` value invoked in `setInfo(meta)` by the party. 

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

For Reliability to be satisfied, sufficiently many copies of `m` must be persisted prior to delivery by any honest party, to guarantee availability against a threshold F of failures. 
There is a very effective way to spread messages reliably while incorporating causality information.
Message digests are echoed by all parties. When 2F+1 echoes are collected, a message can be delivered. 
The details of the echo protocol implementation are omitted here. We remark that echo protocols can be streamlined, resulting in high utilization and throughout (see [Narwhal](..)).

## Fin: BFT Consensus Using Trans DAG 

**Fin** is a simple BFT protocol built using Trans DAG. 
Fin is inspired by PBFT but leverages Trans DAG to have a one-phase commit rule and an extremely simple leader protocol.
The name Fin, a small part of aquatic creatures that controls stirring, stands for the protocol succinctness and its central role in blockchains (and also from the fact that DAT Trans scenarios below look like swarms of fish). 

### Fin Pseudo-code
The pseudo-code for `view(r)` at each party `p` is given in the frame below and explained after it. 

<pre style="font-size: 14px;">

1. <b>Entering a view. </b>
   Upon entering view(r), party p starts a view timer set to expire after a pre-determined view delay. 

2. <b>Proposing. </b>
   The leader leader(r) of view(r) waits to deliver 2F+1 view(r-1) messages or 2F+1 view(-(r-1)) messages, and then invokes setInfo(r). 
     Thereafter, the next transmission by the leader will carry the new view number as indication of proposing in view(r).

3. <b>Voting.</b>
   Each party p other than the leader waits to deliver the first view(r) message from leader(r) and then invokes setInfo(r). 
     Thereafter, the next transmission by p will carry the new view number as indication of voting for the view(r) proposal.

4. <b>Committing. </b>
   A commit of a leader proposal at view(r) with its causal predecessors happens if the DAG maintains the following three conditions:

     (i) A first view(r) message from leader(r), denoted proposal(r), exists. 
     (ii) proposal(r).predecessors refers to either 2F+1 view(r-1) messages or 2F+1 view(-(r-1)) messages (or r=1).
     (iii) First view(r) messages from 2F+1 parties p exist, each having predecessors referring to proposal(r). 

   Upon a commit of proposal(r), a party disarms the view(r) timer.  

5. <b>Expiring the view timer.</b>
   If the view(r) timer expires, a party invokes setInfo(-r). 
     Thereafter, the next transmission by p will carry the negative view number as indication of expiration of r.

7. <b>Advancing to next view.</b>
   A party enters view(r+1) if the DAG satisfies one of the following two conditions:
     (i) A commit of proposal(r) happens.
     (ii) view(-r) messages indicating view(r) expiration from 2F+1 parties exist.
</pre>

### Fin Protocol Description

The Fin protocol works in a view-by-view manner. 

View numbers are embedded in DAG messages using the `setInfo()` API. 
We refer to a message `m` as a _"`view(r)` message"_ if it carries a meta-information field `m.info = r`.
Note, protocol views do *NOT* correspond to DAG layers, but rather, view numbers are explicitly embedded in the meta-information field of messages.

There is a pre-designated leader for `view(r)`, denoted `leader(r)`, which is known to everyone.
`leader(r)` proposes in `view(r)` simply by setting its meta-information value to `r` via `setInfo(r)`. 
The next broadcast transmitted by the leader is interpreted as `proposal(r)`. 
The proposal implicitly extends the sequence of transactions with the transitive causal predecessors of `proposal(r)`. 

In the **Figure 2** below, `leader(r)` is party 1 and its first message in `view(r)` is on layer k denoted with a full yellow oval, 
indicating it is `proposal(r)`. 

When a party receives `proposal(r)`, it advances the meta-information value to `r` view `setInfo(r)`. 
The next broadcast transmitted by the party is interpreted as voting for `proposal(r)`. 

Below, parties 2 and 4 both vote for `proposal(r)` by advancing their view to `r` in layer k+1, denoted with striped yellow ovals. `proposal(r)` now has the required quorum of 2F+1 votes (including the leader's implicit vote), and it becomes committed.

When a party sees 2F+1 votes in `view(r)` it enters `view(r+1)`.
The progress of `view(r+1)` is similar, with party 2 as `leader(r+1)`, its proposal on layer k+2 and votes for it in layer k+3.

  <img src="/images/FIN/propose-commit.png" width="500"  class="center"  />

  **_Figure 2:_** _proposals and votes in `view(r)` and `view(r+1)`, both committed._

If the leader of a view is faulty or disconnected, parties will eventually time out and set their meta-information to minus the view-numver, e.g., `-(r+1)` for a failure of `view(r+1)` . 
Their next broadcasts are interpreted as reporting a failure of `view(r+1)`, enabling `view(r+2)` to start. 

In **Figure 3** below, the first view, `view(r)`, proceeds normally. 
However, no message marked `view(r+1)` by `leader(r+1)` arrives, denoted as a missing oval on layer k+2. 
Parties 1, 3, 4 report this by setting their meta-information to `-(r+1)`, denoted as striped red ovals in layer k+3.

At layer k+4, the leader of `view(r+2)` posts a messages that has meta-information set to `r+2`, taken as `proposal(r+2)`. 
Note that this message has in its causal past messages carrying `-(r+1)` meta-information. 
Hence, faulty views have utility in advancing the global sequence of transaction, just like any other view.

  <img src="/images/FIN/faulty-leader.png" width="750"  class="center"  />

  **_Figure 3:_** _a faulty `view(r+1)` and recovery in `view(r+2)`._


A slightly more complex scenario is depicted in **Figure 4** below. 
Here, `leader(r+1)` emits `proposal(r+1)` in layer k+2 that receives one vote by party 1 in layer k+3.
However, the proposal is too slow to arrive at parties 3 and 4, and both parties report a view failure in layer k+3. There is no quorum enabling a commit in `view(r+1)`, nor entering `view(r+2)`. Eventually, party 1 also times out and reports a failure of `view(r+1)` in layer k+4. This enables `view(r+3)` to start and from here on, the progress of the view is similar to the above.

  <img src="/images/FIN/faulty-leader2.png" width="850"  class="center"  />

  **_Figure 4:_** _a partially faulty `view(r+1)` and recovery in `view(r+2)`._


### Fin Analysis

Fin is minimally integrated into DAG Trans, simply setting a context field periodically.
Importantly, 
at no time is transaction broadcast slowed down by the Fin protocol. 
Rather, Consensus logic is embedded into the DAG structure simply by injecting view numbers into it.

The reliability and causality properties of DAG Trans makes arguing about correctness very easy, 
though a formal proof of correctness is beyond the scope of this post. 
Briefly, the **safety** of commits is as follows. If ever a `view(r)` proposal `proposal(r)` becomes committed, 
then it is in the causal past of 2F+1 parties that voted for it.
Any future view proposal must refer directly or indirectly to 2F+1 `view(r)` messages, of which F+1 are votes for `proposal(r)`.
Hence, any commit of a future view causally follows (hence, transitively re-commits) `proposal(r)`. 

The protocol **liveness** during periods of synchrony stems from two key mechanisms. 

First, after GST (Global Stabilization Time), 
i.e., after communication has become synchronous,
views are inherently synchronized through DAG Trans. 
For let $\Delta$ be an upper bound on communication after GST.
Once a `view(r)` with an honest leader is entered by the first honest party, within $2 * \Delta$, both the leader and all honest parties enter `view(r)` as well. 
Within $4 * \Delta$, the `view(r)` proposal and votes from all honest parties are spread to everyone. 

Second, so long as view timers are set to be at least $4 * \Delta$, a future view does not preempt a current view's commit. For in order to start a new view, 
a leader must collect either 2F+1 `view(r)` _votes_ for the leader proposal, hence commit it; or 2F+1 `view(-r)` _expirations_, which is impossible as argued above. 

Fin is modeled after PBFT while removing the complexity of PBFT's view-change, thus supporting regular leader rotation. 
View-change is the most subtle ingredient of PBFT. 
Simplifying PBFT leveraging DAG Trans is achieved in two ways.
Recall that PBFT works in two-phases. 
The first phase protects against leader equivocation. Building over DAG Trans, non-equivocation is already guaranteed at the transport level, hence Fin foregoes the first phase. 
The second phase of PBFT guards commits by parties locking their votes and transferring them to the next view. 
In particular, a new leader proposal must carry a proof of safety composed of 2F+1 
messages attesting to the highest vote from previous views. 
In Fin, a leader proposal simply references those 2F+1 messages from the previous view.

## DAG Solutions

(This section is still in progress.)

Narwhal is a DAG transport after which DAG Trans is modeled.

Narwhal-HS is a BFT Consensus protocol based on [HotStuff]() for the partial synchrony model,
in which Narwhal is used as a "mempool". 
In order to drive Consensus decisions, 
Narwhal-HS adds messages outside Narwhal, 
using the DAG only for spreading transactions.

DAG-Rider and Tusk build randomized BFT Consensus "riding" on Narwhal for the asynchronous model, 
not exchanging any messages outside the Narwhal protocol. 
These protocols are "zero message overhead" over the DAG, but
Narwhal transmissions are blocked until DAG-Rider (Tusk) injects input values every fourth (second) transmission.

DAG-Rider is designed around "waves". 
In DAG-Rider, each wave consists of 4 DAG layers, at the end of which a leader is elected in retrospect uniformly at random, having constant probability of its proposal becoming committed.
Tusk improves with a 3-layer wave and in overlapping the last layer of each wave with the first one of the next wave.

Bullshark builds BFT Consensus riding on Narwhal for the partial synchrony model.
It is also a "zero message overhead" protocol over the DAG, but due to a rigid wave-by-wave structure, 
Narwhal transmissions are blocked by timers that are internal to the Consensus protocol.
Bullshark is designed with 8-layer waves driving commit, each layer serving a different function in the protocol.

Fin builds BFT Consensus riding on DAG Trans for the partial synchrony model with zero message overhead and no transmission blocking whatsoever.
To achieve Consensus over the DAG Trans, Fin requires only injecting values into transmissions in a non-blocking manner via `setInfo(v)`. 
Once a `setInfo(v)` invocation completes, future emissions by the DAG Trans carry the value `v` in the latest `setInfo(v)` invocation. 
The value `v` is opaque to the DAG Trans and is of interest to the Consensus protocol.

In terms of protocol design, Fin is extremely simple. 
Fin views are a single phase: a leader proposes, parties vote, and commit happens if 2F+1 votes are collected. 
Advancing to the next view is enabled by 2F+1 votes or 2F+1 timeouts. 
That's the whole protocol in two sentences, and proposals, votes, and timeouts can be injected into the DAG at any time, independent of the layer structure. 


| Protocol | Model | Message overhead | Blocking on External Input | Layers to Commit | 
| :---:    | :---: | :---:            | :---:                      | :---: |
| Narwhal-HS | partial-synchrony | yes | no | N/A | 
| DAG-Rider | asynchronous | no | yes | 4 |
| Tusk | asynchronous | no | yes | 2-3 |
| Bullshark | partial-synchrony | no | yes | 8 |
| Fin | partial-synchrony | no | no | 2 (floating) |


There is no question that software modularity is advantageous, since
it removes the Consensus protocol from the critical path of communication.
That said, most solutions do not rely on DAG Trans in a pure black-box manner.
As discussed above, randomized Consensus protocols, e.g.,  DAG-rider and Tusk, inject into the DAG coin-tosses from the Consensus protocol. 
Protocols for the partial synchrony model, e.g., Bullshark, 
delay message transmissions by the transport according to Consensus protocol round timers, 
in order to ensure progress during periods of synchrony. 

In other words, rarely is the case that [all you need is DAG](https://arxiv.org/abs/2102.08325).

Fin finds a sweet-spot in that it injects values into future emissions in a non-intrusive, non-blocking manner.

In a pure DAG-rider solution, parties passively analyze the DAG structure and autonomously arrive at commit ordering decisions. 
No extra messages are exchanged by the Consensus protocol nor is it given an opportunity to inject information into the DAG or control message emission. 
Total and Hashgraph's whitepaper algorithm are pure DAG-rider solutions. Both use randomization to solve Consensus and both are rather theoretical and may suffer prohibitive latencies.
[TODO:] say something about Aleph? Trans? ToTo?


## Reading list

Pre-blockchains era:

* _"Exploiting Virtual Synchrony in Distributed Systems"_, Birman and Joseph, 1987. [[Isis]](https://dl.acm.org/doi/10.1145/37499.37515)

* _"Preserving and Using Context Information in Interprocess Communication"_, Peterson, Buchholz and Schlichting, 1989. [[Psync]](https://dl.acm.org/doi/10.1145/65000.65001)

* _"Broadcast Protocols for Distributed Systems"_, Melliar-Smith, Moser and Agrawala, 1990. [[Trans and Total]](https://ieeexplore.ieee.org/document/80121?tp=&signout=success)

* _"Total Ordering Algorithms"_, Moser, Melliar-Smith and Agrawala, 1991. [[Total (short version)]](https://dl.acm.org/doi/10.1145/327164.327298)

* _"Byzantine-resilient Total Ordering Algorithms"_, Moser and Melliar Smith, 1999. [[Total]](https://www.sciencedirect.com/science/article/pii/S0890540198927705)

* _"Early Delivery Totally Ordered Multicast in Asynchronous Environments"_, Dolev, Kramer and Malki, 1993. [[ToTo]](https://dahliamalkhi.github.io/files/Multicast-FTCS1993.pdf)

* _"The Transis approach to high availability cluster communication"_, Dolev and Malkhi, 1996. [[Transis]](https://dahliamalkhi.github.io/files/Transis-CACM1994.pdf)

Blockchain era:

* _"Hedera: A Public Hashgraph Network & Governing Council"_, Baird, Harman, and Madsen, whitepaper v.2.1., 2020. [[Hedera HashGraph]](https://hedera.com/hh_whitepaper_v2.1-20200815.pdf)

* Aleph [TODO]

* _"Narwhal and Tusk: A DAG-based Mempool and Efficient BFT Consensus"_, Danezis, Kokoris-Kogias, Sonnino, and Spiegelman, 2021. [[Narwhal and Tusk]](https://arxiv.org/abs/2105.11827)

* _"All You Need is DAG"_, Keidar, Kokoris-Kogias, Naor, and Spiegelman, 2021. [[DAG-rider]](https://arxiv.org/abs/2102.08325)

* _"Bullshark: DAG BFT Protocols Made Practical"_, Spiegelman, Giridharan, Sonnino, and Kokoris-Kogias, 2022. [[Bullshark]](https://arxiv.org/abs/2201.05677")

* _"Announcing Narwhal and Tusk Open Source"_, Mysten Labs, 2022. [[Sui]](https://medium.com/mysten-labs/announcing-narwhal-tusk-open-source-3721135abfc3)
