## Away with Monolithic BFT Consensus; Enter DAG-based BFT Consensus

To scale the BFT (Byzantine Fault Tolerant) Consensus core of blockchains,
prevailing wisdom is to separate between two responsibilities. 

* The first is a transport for reliably spreading yet-unconfirmed transactions.
It regulates communication and optimizes throughput, but it tracks only causal ordering in the form of a DAG (Direct Acyclic Graph).

* The second is forming a sequential commit ordering of transactions. 
It must solve BFT Consensus utilizing the transport DAG.

The advent of building Consensus over a DAG transport is that while solving BFT Consensus, parties spread messages that carry useful payloads (e.g., transactions). 
A BFT Consensus protocol can periodically commit batches from the DAG, incurring a tiny cost over the spreading of transactions. 
Moreover, parties can continue sending messages and the DAG keep growing even when Consensus is stalled, e.g., when a Consensus leader is faulty, 
and later commit the messages accumulated in the DAG. 

It is funny how the community made a full circle, from early distributed consensus systems to where we are today. 
I earned my PhD more than two decades ago for contributions to scaling reliable distributed systems, 
guided by and collaborating with pioneers of the field, including
[Ken Birman](https://www.linkedin.com/in/ken-birman-3661a0/), 
[Danny Dolev](https://www.linkedin.com/in/danny-dolev-723aa616/), 
[Rick Schlichting](https://www.linkedin.com/in/rick-schlichting-6519487a/), 
[Michael Melliar-Smith](https://engineering.ucsb.edu/people/p-michael-melliar-smith), 
[Louis Moser](https://engineering.ucsb.edu/people/louise-moser), 
[Robbert van Rennesse](https://www.linkedin.com/in/rvanren/), 
[Yair Amir](https://www.linkedin.com/in/yair-amir-61b58/), 
[Idit Keidar](https://www.linkedin.com/in/idit-keidar-9033287/).
Distributed middleware systems of that time, e.g., 
[Isis](https://dl.acm.org/doi/10.1145/37499.37515), 
[Psync](https://dl.acm.org/doi/10.1145/65000.65001), 
[Trans](https://ieeexplore.ieee.org/document/80121?tp=&signout=success), 
[Total](https://dl.acm.org/doi/10.1145/327164.327298)
and 
[Transis](https://ieeexplore.ieee.org/document/243613), 
were designed for high-throughput by building consensus over causal message ordering (!).
This topic was so much in the spotlight that during 1993-1994,
a debate over the _usefulness of CATOCS (causal and totally ordered communication)_ carried into
several publications of the ACM SIGOPS,
[[CATOCS]](https://dl.acm.org/doi/10.1145/173668.168623)
[[Response 1 to CATOCS]](https://dl.acm.org/doi/10.1145/164853.164859)
[[Response 2 to CATOCS]](https://dl.acm.org/doi/10.1145/164853.164858).

Recent interest in scaling blockchains is rekindling interest in this approach with emphasis on Byzantine fault tolerance, e.g., in 
DAG-based BFT protocols like
[Swirlds hashgraph](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf),
[Blockmania](https://arxiv.org/abs/1809.01620),
[Aleph](https://arxiv.org/pdf/1908.05156.pdf),
[Narwhal & Tusk](https://arxiv.org/abs/2105.11827),
[DAG-rider](https://arxiv.org/abs/2102.08325), and
[Bullshark](https://arxiv.org/abs/2201.05677").

In this post, I will first explain the notion of **DAG Trans**, a reliable, causal broadcast transport that shares a DAG among parties.
I will then demonstrate the utility of DAG Trans through **Fin**, 
quite possibly the simplest and the most efficient novel DAG-riding BFT Consensus solution for the partial synchrony model, 
which the research team at @Chainlink Labs will be developing. 
I will finish with a note on **DAG-riding** BFT Consensus solutions. 

## DAG Trans: Reliable Causal Broadcast 

  <span id="Figure-DAG"> </span>

  <img src="/images/FIN/basic-DAG.png" width="500"  class="center"  />

  **_Figure: DAG Trans._** 
  _A layer-by-layer causality DAG. Each message refers to 2F+1 ones in the preceding layer._ 

DAG Trans is a reliable, causal broadcast communication substrate for disseminating transactions among N=3F+1 parties, at most F of which are presumed Byzantine faulty and the rest are honest.
The substrate exposes three basic API's, `broadcast()`, `deliver()`, and `setInfo()`. 
In a nutshell, DAG Trans guarantees that all parties deliver the same ordered sequence of messages by each sender and exposes a causal-ordering relationship among them. These properties are described below as **Reliability**, **Agreement**, **Validity**, **Integrity**, 
and **Causality**. 

More specifically, DAG Trans provides a `broadcast(payload)` API for a party `p` to send a message to other parties.
A party's upcall `deliver(m)` is triggered when a message `m` can be delivered. 

In this post, we concentrate on a layer-by-layer regime, where in each layer each party is allowed to post only one message, as depicted in [**Figure: DAG Trans**](#Figure-DAG) above. 
The layer-by-layer design regulates transmissions so as to saturate network capacity. 
In this regime, each message must refer to a certain number of messages in the preceding layer and to the sender's own preceding message.

To prepare for Consensus decisions, DAG Trans exposes a single additional API `setInfo(meta)`. 
Whenever a party invokes `broadcast()`, the transmitted message carries the latest `meta` value invoked in `setInfo(meta)` by the party. 

Messages are delivered carrying a sender's payload and additional meta information that can be inspected upon reception.
Every delivered message `m` carries the following fields:

- `m.sender`, the sender identity 
- `m.index`, a delivery index from the sender
- `m.payload`, contents such as transaction(s)
- `m.predecessors`, references to messages sender has seen from other parties, including itself. In a layer-by-layer construction, it includes references to 2F+1 messages in the preceding layer.
- `m.info`, a meta information field reserved for the Consensus protocol to inject through `setInfo()`

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

There is a very effective way to spread messages reliably while incorporating causality information.
For Reliability to be satisfied, sufficiently many copies of `m` must be persisted prior to delivery by any honest party, to guarantee availability against a threshold F of failures. 
To this end, message digests are echoed by all parties. When 2F+1 echoes are collected, a message can be delivered. 
The details of the echo protocol implementation are omitted here. We remark that echo protocols can be streamlined, resulting in high utilization and throughout (see [Narwhal](https://arxiv.org/abs/2105.11827)).

#### A Note on Temporary Disconnections

Sometimes, a party may become temporarily disconnected. When it reconnects back, the DAG might have grown many layers without it.
It is undesirable that a reconnecting party would be required to backfill every layer it missed with messages that everyone has to catch up with.
Therefore, parties are allowed to refer to their own preceding message across (skipped) layers, as depicted in [**Figure: Disconnect**](#Figure-Disconnect) below. 

  <span id="Figure-Disconnect"></span>

  <img src="/images/FIN/basic-DAG2.png" width="500"  class="center"  />

  **_Figure: Disconnect._** 
  _A temporary disconnect of party 4 and a later reconnect._ 

## Fin

**Fin** is quite possibly the simplest and the most efficient DAG-riding BFT Consensus solution for the partial synchrony model. 

Fin operates in a view-by-view manner, with a single phase propose-vote commit rule embedded into the DAG: a leader proposes, parties vote, and commit happens when 2F+1 votes are collected. 
Advancing to the next view is enabled by 2F+1 votes or 2F+1 timeouts. 
Proposals, votes, and timeouts are injected into the DAG at any time, independent of layers, 
simply by updating a view number through `setInfo()`.

Fin is inspired by PBFT but leverages Trans DAG to have a one-phase commit rule and an extremely simple leader protocol.
Fin is meant for demonstration purposes, not as a full-fledged BFT Consensus system design. The main takeaway from Fin is that **by separating reliable transaction dissemination from Consensus, BFT Consensus based on DAG Trans can be made simple and highly performant at the same time**.

The name Fin, a small part of aquatic creatures that controls stirring, stands for the protocol succinctness and its central role in blockchains (and also because the DAG Trans scenarios below look like swarms of fish, and DAG in Hebrew means fish). 

### Fin Pseudo-code

The pseudo-code for `view(r)` at each party `p` is given in the frame below, and a verbal explanation is providing below it. 

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
   A commit of a leader proposal at view(r) happens if the DAG maintains the following three conditions:
     (i) A first view(r) message from leader(r), denoted proposal(r), exists. 
     (ii) proposal(r).predecessors refers to either 2F+1 view(r-1) messages or 2F+1 view(-(r-1)) messages (or r=1).
     (iii) First view(r) messages from 2F+1 parties p exist, each having predecessors referring to proposal(r). 

   Upon a commit of proposal(r), a party disarms the view(r) timer.  

   4.1. <b>Ordering commits. </b>

   If `proposal(r)` commits, messages are appended to the committed sequence as follows. 
   First, among `proposal(r)`'s causal predecessors, the highest `proposal(r')` that has F+1 votes is
   (recursively) ordered. 
   After it, remaining causal predecessors of `proposal(r)` which have not yet been ordered are appended to the committed sequence
   (within this batch, ordering can be done using any deterministic rule to linearize the partial ordering into a total ordering.)

5. <b>Expiring the view timer.</b>
   If the view(r) timer expires, a party invokes setInfo(-r). 
     Thereafter, the next transmission by p will carry the negative view number as indication of expiration of r.

6. <b>Advancing to next view.</b>
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
Thereafter, transmissions by the leader will carry the new view number. 
The first `view-r` message by the leader carrying `view(r) is interpreted as `proposal(r)`. 
The proposal implicitly extends the sequence of transactions with the transitive causal predecessors of `proposal(r)`. 

In [**Figure: Commit**](#Figure-Commit) below, `leader(r)` is party 1 and its first message in `view(r)` is on layer k denoted with a full yellow oval, 
indicating it is `proposal(r)`. 

When a party receives `proposal(r)`, it advances the meta-information value to `r` view `setInfo(r)`. 
Thereafter, transmissions by the party will carry the new view number and be interpreted as voting for `proposal(r)`. 
A proposal that has a quorum of 2F+1 votes is considered **committed**.

Below, parties 3 and 4 vote for `proposal(r)` by advancing their view to `r` in layer k+1, denoted with striped yellow ovals. `proposal(r)` now has the required quorum of 2F+1 votes (including the leader's implicit vote), and it becomes committed.

When a party sees 2F+1 votes in `view(r)` it enters `view(r+1)`.

An important feature of Fin is that votes may arrive at different layers without slowing down progress. 
Layers meanwhile fill with useful messages that may become committed at the next view.

This feature is demonstrated in the scenario below at `view(r+1)`.
The view has party 2 as `leader(r+1)`, party 3 voting at layer k+3, and parties 1 and 4 at layer k+4.
After layer k+4, `proposal(r+1)` has the necessary quorum of 2F+1 of votes to become committed. 
Meanwhile, layers k+2, k+3 and k+4 fill with messages that may become committed at the next view.

  <span id="Figure-Commit"></span>

  <img src="/images/FIN/propose-commit.png" width="625"  class="center"  />

  **_Figure: Commit._** 
  _Proposals and votes in `view(r)` and `view(r+1)`, both committed._

If the leader of a view is faulty or disconnected, parties will eventually time out and set their meta-information to minus the view-number, e.g., `-(r+1)` for a failure of `view(r+1)` . 
Their next broadcasts are interpreted as reporting a failure of `view(r+1)`. 
When a party sees 2F+1 reports that `view(r+1)` is faulty it enters `view(r+2)`. 

In [**Figure: Fault**](#Figure-Fault) below, the first view `view(r)` proceeds normally. 
However, no message marked `view(r+1)` by `leader(r+1)` arrives, showing as a missing oval on layer k+2. 
Parties 1, 3, 4 report this by setting their meta-information to `-(r+1)`, showing as striped red ovals in layer k+3.

At layer k+4, the leader of `view(r+2)` posts a messages that has meta-information set to `r+2`, taken as `proposal(r+2)`. 
Note that this message has in its causal past messages carrying `-(r+1)` meta-information. 
Hence, faulty views have utility in advancing the global sequence of transaction, just like any other view.

  <span id="Figure-Fault"></span>

  <img src="/images/FIN/faulty-leader.png" width="750"  class="center"  />

  **_Figure: Fault._** 
  _A faulty `view(r+1)` and recovery in `view(r+2)`._


A slightly more complex scenario is depicted in [**Figure: Partial-Fault**](#Figure-Partial-Fault) below. 
Here, `leader(r+1)` emits `proposal(r+1)` in layer k+2 that receives one vote by party 1 in layer k+3.
However, the proposal is too slow to arrive at parties 3 and 4, and both parties report a view failure in layer k+3. There is no quorum enabling a commit in `view(r+1)`, nor entering `view(r+2)`. Eventually, party 1 also times out and reports a failure of `view(r+1)` in layer k+4. This enables `view(r+3)` to start and from here on, the progress of the view is similar to the above.

  <span id="Figure-Partial-Fault"></span>

  <img src="/images/FIN/faulty-leader2.png" width="850"  class="center"  />

  **_Figure: Partial-Fault._** 
  _A partially faulty `view(r+1)` and recovery in `view(r+2)`._ 


### Fin Analysis

Fin is minimally integrated into DAG Trans, simply setting the meta-information field periodically.
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

## DAG-based Solutions

[Narwhal](https://arxiv.org/abs/2105.11827) is a DAG transport after which DAG Trans is modeled.

[Narwhal-HS](https://arxiv.org/abs/2105.11827) is a BFT Consensus protocol based on [HotStuff]() for the partial synchrony model,
in which Narwhal is used as a "mempool". 
In order to drive Consensus decisions, 
Narwhal-HS adds messages outside Narwhal, 
using the DAG only for spreading transactions.

[DAG-Rider](https://arxiv.org/abs/2102.08325) and
[Tusk](https://arxiv.org/abs/2105.11827)
build randomized BFT Consensus for the asynchronous model "riding" on Narwhal, 
These protocols are "zero message overhead" over the DAG, not exchanging any messages outside the Narwhal protocol.
However, DAG-Rider (Tusk) must inject input value every 4 (2) layers, 
which means that Narwhal transmissions are blocked on Consensus protocol actions.

[Bullshark](https://arxiv.org/abs/2201.05677")
builds BFT Consensus riding on Narwhal for the partial synchrony model.
It is also a "zero message overhead" protocol over the DAG, but due to a rigid wave-by-wave structure, 
Narwhal transmissions are blocked by timers that are internal to the Consensus protocol.
Bullshark is designed with 8-layer waves driving commit, each layer serving a different function in the protocol.

Fin builds BFT Consensus riding on DAG Trans for the partial synchrony model with "zero message overhead".
Uniquely, it incurs no transmission blocking whatsoever.
To achieve Consensus over DAG Trans, Fin requires only injecting values into transmissions in a non-blocking manner via `setInfo(v)`. 
Once a `setInfo(v)` invocation completes, future emissions by the DAG Trans carry the value `v` in the latest `setInfo(v)` invocation. 
The value `v` is opaque to the DAG Trans and is of interest to the Consensus protocol.

In terms of protocol design, all of the above solutions are relatively succinct, but arguably, Fin is the simplest.
DAG-Rider, Tusk and Bullshark are multi-stage protocols embedded into DAG multi-layer "waves" (4 layers in DAG-Rider, 2-3 in Tusk, 8 in Bullshark).
Each layer is used for a different stage in the Consensus protocol, with a potential commit happening at the last layer. 
Fin is single-stage, and view numbers can be injected into the DAG at any time, independent of the layer structure. 


| Protocol | Model | External Msgs | Layered DAG | Blocking     | Layers to Commit | 
| :--- | :--- | :--- | :--- | :-- | :--- |
| [Total](https://www.sciencedirect.com/science/article/pii/S0890540198927705) | asynchronous | none | no | no | eventual |
| [Swirlds Hashgraph](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf) | asynchronous | none | no | no | eventual |
| [Aleph](https://arxiv.org/pdf/1908.05156.pdf) | asynchronous | none | yes | yes (coin input) | expected constant |
| [Narwhal-HS](https://arxiv.org/abs/2105.11827) | partial-synchrony | yes | yes | no | N/A | 
| [DAG-Rider](https://arxiv.org/abs/2102.08325) | asynchronous | none | yes | yes (coin input) | expected constant |
| [Tusk](https://arxiv.org/abs/2105.11827) | asynchronous | none | yes | yes  (coin input) | expected constant |
| [Bullshark](https://arxiv.org/abs/2201.05677") | partial-synchrony | none | yes | yes (timers) | 8 |
| Fin | partial-synchrony | none | yes | no | 2 (floating) |


There is no question that software modularity is advantageous, since
it removes the Consensus protocol from the critical path of communication.
That said, most solutions do not rely on a DAG-based transport in a pure black-box manner.
As discussed above, randomized Consensus protocols, e.g.,  DAG-rider and Tusk, inject into the DAG coin-tosses from the Consensus protocol. 
Protocols for the partial synchrony model, e.g., Bullshark, 
delay message transmissions by the transport according to Consensus protocol round timers, 
in order to ensure progress during periods of synchrony. 

In other words, rarely is the case that [all you need is DAG](https://arxiv.org/abs/2102.08325).

In a pure DAG-rider solution,
no extra messages are exchanged by the Consensus protocol nor is it given an opportunity to inject information into the DAG or control message emission. 
Parties passively analyze the DAG structure and autonomously arrive at commit ordering decisions,
even though the DAG is delivered to parties incrementally and in potentially different order.

[Total](https://www.sciencedirect.com/science/article/pii/S0890540198927705) and
[ToTo](https://dahliamalkhi.github.io/files/Multicast-FTCS1993.pdf)
are pre- blockchain era, pure DAG-rider total ordering protocols for the asynchronous model. 
[Swirlds Hashgraph](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf)
is the only post- blockchain era, pure DAG-rider solution to our knowledge. 
It makes use of bits within messages as pseudo-random coin tosses in order to drive randomized Consensus.
All of the above pure DAG protocols are designed without regulating DAG layers, and without injecting external common coin-flips to cope with asynchrony. 
As a result, they are both quite complex and their convergence slow. 

Fin finds a sweet-spot in that -- albeit not being a pure DAG-rider -- it is a simple and fast DAG-based protocol, that injects values 
into the DAG in a non-intrusive manner.


## Reading list

Pre-blockchains era:

* _"Exploiting Virtual Synchrony in Distributed Systems"_, Birman and Joseph, 1987. [[Isis]](https://dl.acm.org/doi/10.1145/37499.37515)

* _"Preserving and Using Context Information in Interprocess Communication"_, Peterson, Buchholz and Schlichting, 1989. [[Psync]](https://dl.acm.org/doi/10.1145/65000.65001)

* _"Broadcast Protocols for Distributed Systems"_, Melliar-Smith, Moser and Agrawala, 1990. [[Trans and Total]](https://ieeexplore.ieee.org/document/80121?tp=&signout=success)

* _"Total Ordering Algorithms"_, Moser, Melliar-Smith and Agrawala, 1991. [[Total (short version)]](https://dl.acm.org/doi/10.1145/327164.327298)

* _"Byzantine-resilient Total Ordering Algorithms"_, Moser and Melliar Smith, 1999. [[Total]](https://www.sciencedirect.com/science/article/pii/S0890540198927705)

* _"Transis: A Communication System for High Availability"_, Amir, Dolev, Kramer, Malkhi, 1992. [[Transis]](https://ieeexplore.ieee.org/document/243613)

* _"Early Delivery Totally Ordered Multicast in Asynchronous Environments"_, Dolev, Kramer and Malki, 1993. [[ToTo]](https://dahliamalkhi.github.io/files/Multicast-FTCS1993.pdf)

* _"Understanding the Limitations of Causally and Totally Ordered Communication"_, Cheriton and Skeen, 1993. [[CATOCS]](https://dl.acm.org/doi/10.1145/173668.168623)

* _"Why Bother with CATOCS?"_, Van Renesse, 1994. [[Response 1 to CATOCS]](https://dl.acm.org/doi/10.1145/164853.164859)

* _"A Response to Cheriton and Skeen's Criticism of Causal and Totally Ordered Communication"_, Birman, 1994. [[Response 2 to CATOCS]](https://dl.acm.org/doi/10.1145/164853.164858)

Blockchain era:

* _"The Swirlds Hashgraph Consensus Algorithm: Fair, Fast, Byzantine Fault Tolerance"_, Baird, 2016. [[Swirlds Hashgraph]](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf)

* _"Blockmania: from Block DAGs to Consensus"_. Danezis and Hrycyszyn, 2018. [[Blockmania]](https://arxiv.org/abs/1809.01620).

* _"Aleph: Efficient Atomic Broadcast in Asynchronous Networks with Byzantine Nodes"_, Gągol, Leśniak, Straszak, and Świętek, 2019. [[Aleph]](https://arxiv.org/pdf/1908.05156.pdf)

* _"Narwhal and Tusk: A DAG-based Mempool and Efficient BFT Consensus"_, Danezis, Kokoris-Kogias, Sonnino, and Spiegelman, 2021. [[Narwhal and Tusk]](https://arxiv.org/abs/2105.11827)

* _"All You Need is DAG"_, Keidar, Kokoris-Kogias, Naor, and Spiegelman, 2021. [[DAG-rider]](https://arxiv.org/abs/2102.08325)

* _"Bullshark: DAG BFT Protocols Made Practical"_, Spiegelman, Giridharan, Sonnino, and Kokoris-Kogias, 2022. [[Bullshark]](https://arxiv.org/abs/2201.05677")

