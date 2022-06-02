  <img src="/images/FIN/cover.png" width="600"  class="center"  />

## Away Monolithic BFT Consensus; Enter DAG-based BFT Consensus

To scale the BFT (Byzantine Fault Tolerant) Consensus core of blockchains,
prevailing wisdom is to separate between two responsibilities. 

* The first is a transport for reliably spreading yet-unconfirmed transactions.
It regulates communication and optimizes throughput, but it tracks only causal ordering in the form of a DAG (Direct Acyclic Graph).

* The second is forming a sequential commit ordering of transactions. 
It solves BFT Consensus utilizing the DAG.

The advent of building Consensus over a DAG transport is that each message in the DAG spreads useful payloads (transactions).
Each time a party sends a message with transactions, it also contributes at no cost (or a tiny additional cost) to forming a Consensus total ordering of committed transactions.
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
If you are like me, you might feel that these solutions are a bit overdone:
they contain multiple purpose-built DAG layers, and furthermore,
DAG transmissions are blocked on input needed for specific layers from the Consensus protocol, potentially hampering throughput. 
Since the DAG already solves ninety percent of the BFT Consensus problem by supporting reliable,
causally ordered broadcast, it seems that we should be able to do simpler/better.

**In this post, I will illustrate a simple --
quite possibly the simplest and the most efficient -- DAG-riding BFT Consensus solution, _Fin_, for the partial synchrony model.**
Fin views consist of a proposal followed by 2F+1 votes to commit, the most straight-forward protocol you can imagine.
Both proposals and votes are cast by parties simply setting a single value inside messages. 
Importantly and uniquely, DAG transmissions are never blocked on such values being injected, 
thus Fin operates without hampering DAG throughput whatsoever. 

Fin is meant for pedagogical purposes, not as a full-fledged BFT Consensus system design. The main takeaway from Fin is that by separating reliable transaction dissemination from Consensus, BFT Consensus based on DAG Trans can be made simple and highly performant at the same time.

The name Fin, a small part of aquatic creatures that controls stirring, stands for the protocol succinctness and its central role in blockchains (and also because the scenarios depicted below look like swarms of fish, and DAG in Hebrew means fish). 

  <img src="/images/FIN/fish.png" />

The post is organized as follows:

* The first section, [**DAG Trans**](#DAG-Trans), 
explains the notion of a reliable, causal broadcast transport that shares a DAG among parties. 

* The second section, [**Fin**](#FIN), 
demonstrates the utility of DAG Trans through **Fin**,
a BFT solution which is one-phase, non-blocking, DAG-riding and designed for the partial synchrony model.

* The third section, [**DAG-riding**](#DAG-Riding), 
contains comparison notes on DAG-based BFT Consensus solutions. 

* Further reading materials are listed in [**DAG-based BFT Consensus Reading list**](#DAG-Reading).


<span id="DAG-Trans"> </span>
## DAG Trans: A Reliable Causal Broadcast Transport

  <span id="Figure-DAG"> </span>

  <img src="/images/FIN/SWARMING.png" />

  **_Figure 1:_** 
  _A causality graph of messages, each message "fin" refers to preceding messages._ 

DAG Trans is a reliable, causal broadcast communication substrate for disseminating transactions among N=3F+1 parties, at most F of which are presumed Byzantine faulty and the rest are honest.
The substrate exposes three basic API's, `broadcast()`, `deliver()`, and `setInfo()`. 
In a nutshell, DAG Trans guarantees that all parties deliver the same ordered sequence of messages by each sender and exposes a causal-ordering relationship among them. These properties are described below as **Reliability**, **Agreement**, **Validity**, **Integrity**, 
and **Causality**. 

More specifically, DAG Trans provides a `broadcast(payload)` API for a party `p` to send a message to other parties.
A party's upcall `deliver(m)` is triggered when a message `m` can be delivered. 
Each message must refer to a certain number of preceding messages including the sender's own preceding message.
To prepare for Consensus decisions, DAG Trans exposes a single additional API `setInfo(meta)`. 
Whenever a party invokes `broadcast()`, the transmitted message carries the latest `meta` value invoked in `setInfo(meta)` by the party. 

  **Layer-by-layer construction.** Transports are often constructed in layer-by-layer regime, as depicted in [**Figure 1**](#Figure-DAG) above. In this regime, each sender is allowed one message per layer, and a message may refer only to messages in the layer preceding it.
  Layering is done so as to regulate transmissions and saturate network capacity, but these considerations are orthogonal to the BFT Consensus protocol. As we shall see below, Fin ignores a layer structure of DAG Trans, if exists.

Messages are delivered carrying a sender's payload and additional meta information that can be inspected upon reception.
Every delivered message `m` carries the following fields:

- `m.sender`, the sender identity 
- `m.index`, a delivery index from the sender
- `m.payload`, contents such as transaction(s)
- `m.predecessors`, references to messages sender has seen from other parties, including itself. 
     - In a layer-by-layer construction, it includes references to messages in the preceding layer.
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

#### Layers and Temporary Disconnections

Sometimes, a party may become temporarily disconnected. When it reconnects back, the DAG might have grown many layers without it.
It is undesirable that a reconnecting party would be required to backfill every layer it missed with messages that everyone has to catch up with.
Therefore, parties are allowed to refer to their own preceding message across (skipped) layers, as depicted in [**Figure 2**](#Figure-Disconnect) below. 

  <span id="Figure-Disconnect"></span>

  <img src="/images/FIN/basic-DAG2.png" width="750"  class="center"  />

  **_Figure 2:_** 
  _A temporary disconnect of party 4 and a later reconnect._ 


<span id="FIN"></span>
## Fin

**Fin** is quite possibly the simplest and the most efficient DAG-riding BFT Consensus solution for the partial synchrony model. 

Fin operates in a view-by-view manner, each view consisting of a propose-vote commit rule embedded into the DAG: 
a leader proposes, parties vote, and commit happens when 2F+1 votes are collected. 
There is no need to worry about a leader equivocating, because Trans DAG prevents equivocation,
and there is no need for a leader to justify its proposal because it is inherently justified through the proposal's causal history within the DAG.
Advancing to the next view is enabled by 2F+1 votes or 2F+1 timeouts. 
This guarantees that if a proposal becomes committed, the next (justified) leader proposal contains F+1 references to it. 
Importantly, proposals, votes, and timeouts are injected into the DAG at any time, independent of layers, 
simply by updating a view number through `setInfo()`.

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

   If proposal(r) commits, messages are appended to the committed sequence as follows. 
   First, among proposal(r)'s causal predecessors, the highest proposal(r') that has F+1 votes is
   (recursively) ordered. 
   After it, remaining causal predecessors of proposal(r) which have not yet been ordered are appended to the committed sequence
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

In [**Figure 3**](#Figure-Commit) below, `leader(r)` is party 1 and its first message in `view(r)` is denoted with a full yellow oval, 
indicating it is `proposal(r)`. 

When a party receives `proposal(r)`, it advances the meta-information value to `r` view `setInfo(r)`. 
Thereafter, transmissions by the party will carry the new view number and the first of them be interpreted as voting for `proposal(r)`. 
A proposal that has a quorum of 2F+1 votes is considered **committed**.

Below, parties 3 and 4 vote for `proposal(r)` by advancing their view to `r`, denoted with striped yellow ovals. `proposal(r)` now has the required quorum of 2F+1 votes (including the leader's implicit vote), and it becomes committed.

When a party sees 2F+1 votes in `view(r)` it enters `view(r+1)`.

An important feature of Fin is that votes may arrive without slowing down progress. 
The DAG meanwhile fill with useful messages that may become committed at the next view.
This feature is demonstrated in the scenario below at `view(r+1)` that has party 2 as `leader(r+1)`.
Once `proposal(r+1)` has the necessary quorum of 2F+1 of votes, it becomes committed. 
Meanwhile, the DAG fills with messages that may become committed at the next view.

  <span id="Figure-Commit"></span>

  <img src="/images/FIN/propose-commit.png" width="750"  class="center"  />

  **_Figure 3:_** 
  _Proposals and votes in `view(r)` and `view(r+1)`, both committed._

If the leader of a view is faulty or disconnected, parties will eventually time out and set their meta-information to minus the view-number, e.g., `-(r+1)` for a failure of `view(r+1)` . 
Their next broadcasts are interpreted as reporting a failure of `view(r+1)`. 
When a party sees 2F+1 reports that `view(r+1)` is faulty it enters `view(r+2)`. 

In [**Figure 4**](#Figure-Fault) below, the first view `view(r)` proceeds normally. 
However, no message marked `view(r+1)` by `leader(r+1)` arrives, showing as a missing oval. 
Parties 1, 3, 4 report this by setting their meta-information to `-(r+1)`, showing as striped red ovals.

After 2F+1 reports are collected, the leader of `view(r+2)` posts a messages that has meta-information set to `r+2`, taken as `proposal(r+2)`. 
Note that this message has in its causal past messages carrying `-(r+1)` meta-information. 
Hence, faulty views have utility in advancing the global sequence of transaction, just like any other view.

  <span id="Figure-Fault"></span>

  <img src="/images/FIN/faulty-leader.png" width="750"  class="center"  />

  **_Figure 4:_** 
  _A faulty `view(r+1)` and recovery in `view(r+2)`._


A slightly more complex scenario is depicted in [**Figure 5**](#Figure-Partial-Fault) below. 
Here, `leader(r+1)` emits `proposal(r+1)` that receives one vote by party 1.
However, the proposal is too slow to arrive at parties 3 and 4, and both parties report a view failure.
There is no quorum enabling a commit in `view(r+1)`, nor entering `view(r+2)`. Eventually, party 1 also times out and reports a failure of `view(r+1)`. This enables `view(r+2)` to start. `view(r+2)` is similar to the scenario in [**Figure 4**](#Figure-Fault) above, except that when `proposal(r+2)` commits, it indirectly commits `proposal(r+1)`. 

  <span id="Figure-Partial-Fault"></span>

  <img src="/images/FIN/faulty-leader2.png" width="750"  class="center"  />

  **_Figure 5:_** 
  _A partially faulty `view(r+1)` and recovery in `view(r+2)`._ 


### Fin Analysis

Fin is minimally integrated into DAG Trans, simply setting the meta-information field periodically.
Importantly, 
at no time is transaction broadcast slowed down by the Fin protocol. 
Rather, Consensus logic is embedded into the DAG structure simply by injecting view numbers into it.

The reliability and causality properties of DAG Trans makes arguing about correctness very easy, 
though a formal proof of correctness is beyond the scope of this post. 

* **Safety.** 
  Briefly, the safety of commits is as follows. If ever a `view(r)` proposal `proposal(r)` becomes committed, 
then it is in the causal past of 2F+1 parties that voted for it.
Any future view proposal must refer directly or indirectly to 2F+1 `view(r)` messages, of which F+1 are votes for `proposal(r)`.
Hence, any commit of a future view causally follows (hence, transitively re-commits) `proposal(r)`. 

* **Liveness.** The protocol liveness during periods of synchrony stems from two key mechanisms. 

  First, after GST (Global Stabilization Time), 
i.e., after communication has become synchronous,
views are inherently synchronized through DAG Trans. 
For let $\Delta$ be an upper bound on communication after GST.
Once a `view(r)` with an honest leader is entered by the first honest party, within $2 * \Delta$, both the leader and all honest parties enter `view(r)` as well. 
Within $4 * \Delta$, the `view(r)` proposal and votes from all honest parties are spread to everyone. 

  Second, so long as view timers are set to be at least $4 * \Delta$, a future view does not preempt a current view's commit. For in order to start a new view, 
a leader must collect either 2F+1 `view(r)` _votes_ for the leader proposal, hence commit it; or 2F+1 `view(-r)` _expirations_, which is impossible as argued above. 

Fin is modeled after PBFT while removing the complexity of PBFT's view-change, thus supporting regular leader rotation. 
Simplifying PBFT leveraging DAG Trans is achieved in two ways.
Recall that PBFT works in two-phases. 
The first phase protects against leader equivocation. Building over DAG Trans, non-equivocation is already guaranteed at the transport level, hence Fin foregoes the first phase. 
The second phase of PBFT guards commits by parties locking their votes and transferring them to the next view. 
View-change is the most subtle ingredient of PBFT; 
in particular, a new leader proposal must carry a proof of safety composed of 2F+1 
messages attesting to the highest vote from previous views. 
In Fin, a leader proposal simply references those 2F+1 messages from the previous view.

Last, we remark about Fin's communication complexity. 

* **DAG message cost**: In order for DAG messages to be delivered reliably, it must implement reliable broadcast.
This incurs either a quadratic number of messages carried over authenticated channels, or a quadratic number of signature verifications, per broadcast. 
In either case, the quadratic cost may be amortized by pipelining, driving it is practice to (almost) linear per broadcast.

* **Commit message cost**: Fin sends n broadcast messages, a proposal and votes, per decision. 
A decision commits the causal history of the proposal, consisting of (at least) a linear number of messages. Moreover, each message may carry multiple transaction in its payload.
As a result, in practice the commit cost is amortized over many transactions.

* **Commit latency**: The commit latency in terms of DAG messages is 2, one proposal followed by votes.

Protocols for the partial synchrony model have unbounded worst case by nature, hence, we concentrate on the costs incurred during steady state when a leader is honest and communication with it is synchronous:

<span id="DAG-Riding"></span>
## DAG-based Solutions

[Narwhal](https://arxiv.org/abs/2105.11827) is a DAG transport after which DAG Trans is modeled. It has a layer-by-layer structure, each layer having at most one message per sender and referring to 2F+1 messages in the preceding layer.

[Narwhal-HS](https://arxiv.org/abs/2105.11827) is a BFT Consensus protocol based on [HotStuff]() for the partial synchrony model,
in which Narwhal is used as a "mempool". 
In order to drive Consensus decisions, 
Narwhal-HS adds messages outside Narwhal, 
using the DAG only for spreading transactions.

[DAG-Rider](https://arxiv.org/abs/2102.08325) and
[Tusk](https://arxiv.org/abs/2105.11827)
build randomized BFT Consensus for the asynchronous model "riding" on Narwhal, 
These protocols are "zero message overhead" over the DAG, not exchanging any messages outside the Narwhal protocol.
DAG-Rider (Tusk) is structured with purpose-built DAG layers grouped into "waves" of 4 (2) layers each. 
The Consensus protocol must inject input value every wave, 
which means that Narwhal transmissions are blocked on Consensus protocol actions.

[Bullshark](https://arxiv.org/abs/2201.05677")
builds BFT Consensus riding on Narwhal for the partial synchrony model.
It is also a "zero message overhead" protocol over the DAG, but due to a rigid wave-by-wave structure, 
Narwhal transmissions are blocked by timers that are internal to the Consensus protocol.
Bullshark is designed with 8-layer waves driving commit, each layer purpose-built to serve a different step in the protocol.

Fin builds BFT Consensus riding on DAG Trans for the partial synchrony model with "zero message overhead".
Uniquely, it incurs no transmission blocking whatsoever.
To achieve Consensus over DAG Trans, Fin requires only injecting values into transmissions in a non-blocking manner via `setInfo(v)`. 
Once a `setInfo(v)` invocation completes, future emissions by the DAG Trans carry the value `v` in the latest `setInfo(v)` invocation. 
The value `v` is opaque to the DAG Trans and is of interest to the Consensus protocol.

In terms of protocol design, all of the above solutions are relatively succinct, but arguably, Fin is the simplest.
DAG-Rider, Tusk and Bullshark are multi-stage protocols embedded into DAG multi-layer "waves" (4 layers in DAG-Rider, 2-3 in Tusk, 8 in Bullshark).
Each layer is purpose-build for a different step in the Consensus protocol, with a potential commit happening at the last layer. 
Fin is single-phase, and view numbers can be injected into the DAG at any time, independent of the layer structure. 


| Protocol | Model | External messages used | DAG must be layered | Transmission blocking | Commit latency in DAG rounds | 
| :--- | :--- | :--- | :--- | :-- | :--- |
| [Total](https://www.sciencedirect.com/science/article/pii/S0890540198927705) | asynchronous | none | no | no | eventual |
| [Swirlds Hashgraph](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf) | asynchronous | none | no | no | eventual |
| [Aleph](https://arxiv.org/pdf/1908.05156.pdf) | asynchronous | none | yes | yes (coin input) | expected constant |
| [Narwhal-HS](https://arxiv.org/abs/2105.11827) | partial-synchrony | yes | yes | no | 3 | 
| [DAG-Rider](https://arxiv.org/abs/2102.08325) | asynchronous | none | yes | yes (coin input) | expected constant (4?) |
| [Tusk](https://arxiv.org/abs/2105.11827) | asynchronous | none | yes | yes  (coin input) | expected constant (3?) |
| [Bullshark](https://arxiv.org/abs/2201.05677") | partial-synchrony | none | yes | yes (timers) | 8 |
| Fin | partial-synchrony | none | no | no | 2 |


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
is the only blockchain era, pure DAG-rider solution to our knowledge. 
It makes use of bits within messages as pseudo-random coin tosses in order to drive randomized Consensus.
All of the above pure DAG protocols are designed without regulating DAG layers, and without injecting external common coin-flips to cope with asynchrony. 
As a result, they are both quite complex and their convergence slow. 

Fin finds a sweet-spot: albeit not being a pure DAG-rider, it is a simple and fast DAG-based protocol, that injects values 
into the DAG in a non-intrusive manner.



<span id="DAG-Reading"></span>
## DAG-based BFT Consensus: Reading list

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

* _"Blockmania: from Block DAGs to Consensus"_, Danezis and Hrycyszyn, 2018. [[Blockmania]](https://arxiv.org/abs/1809.01620).

* _"Aleph: Efficient Atomic Broadcast in Asynchronous Networks with Byzantine Nodes"_, Gągol, Leśniak, Straszak, and Świętek, 2019. [[Aleph]](https://arxiv.org/pdf/1908.05156.pdf)

* _"Narwhal and Tusk: A DAG-based Mempool and Efficient BFT Consensus"_, Danezis, Kokoris-Kogias, Sonnino, and Spiegelman, 2021. [[Narwhal and Tusk]](https://arxiv.org/abs/2105.11827)

* _"All You Need is DAG"_, Keidar, Kokoris-Kogias, Naor, and Spiegelman, 2021. [[DAG-rider]](https://arxiv.org/abs/2102.08325)

* _"Bullshark: DAG BFT Protocols Made Practical"_, Spiegelman, Giridharan, Sonnino, and Kokoris-Kogias, 2022. [[Bullshark]](https://arxiv.org/abs/2201.05677")


