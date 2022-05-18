## Away monolithic BFT consensus systems, enter DAG-based BFT consensus

To scale BFT (Byzantine Fault Tolerant) Consensus, prevailing wisdom is to
separate between two responsibilities. The first is message dissemination. A network gossip 
substrate is responsible for providing reliable and causal dissemination of yet-unconfirmed transactions. 
It regulates communication and optimizes throughput, but it tracks only causal ordering. The causal order is exposed by the gossip layer to higher layers as a DAG (Direct Acyclic Graph) of messages.
The second responsibility is a consistency and safety layer. 
It forms a sequential ordering of transactions and determines a commit finality. It solves consensus utilizing the gossip DAG.

It is funny how the community made a full circle coming from early distributed consensus systems 
to where we are today. 
I earned my PhD working alongside pioneers in distributed systems like @Ken Birman, @Danny Dolev, @Rick Schlichting, @Michael Melliar-Smith, @Louis Moser, @Robbert van Rennesse, @Yair Amir, @Idit Keidar, and others. More than two decades ago, distributed systems like Isis, Psync, Trans, Total and Transis, 
achieved high throughput by building consensus over a causal message ordering substrate.
Recent interest in scaling the core of BFT Consensus blockchains rekindled this approach in a line of works, e.g., . 
[HashGraph](https://hedera.com/hh_whitepaper_v2.1-20200815.pdf),
[Narwal](),
[DAG-rider](),
[Bullshark](https://arxiv.org/abs/2201.05677"),
[Sui](). 

There is no question that software modularity is advantageous, though
most of these solutions do not rely on a DAG in a black-box manner. 
For example, randomized consensus protocols like DAG-rider and Tusk inject into the DAG coin-tosses from the consensus protocol. Protocols like Bullshark control message emissions according the consensus protocol round timers in order to ensure progress during periods of synchrony. 
In other words, rarely is the case that [all you need is a DAG](https://arxiv.org/abs/2102.08325).

In this post, I will do three things. I will explain the notion of a reliable and causal messaging substrate. I will then demonstrate an extremely simple one-round BFT consensus using it. Like Bullshark, it is not a black-box solution, it controls message emissions according to round timers. I will finish with a note on DAG-riders, pure DAG solutions that extract consensus passively and autonomously solely based on the DAG structure, with no extra information exchanged.


## Reliable, Causal Broadcast 

![](/images/FIN/basic-DAG.png width="500")
     _Basic layer-by-layer causality DAG. Each node refers to 2F+1 in preceding layer._

<img src="/images/FIN/basic-DAG.png" width="500"  class="center"  />
     _Basic layer-by-layer causality DAG. Each node refers to 2F+1 in preceding layer._

Under the name gossip is a communication substrate for disseminating and processing messages in memory to prepare for a commit consensus decision. 
The formal requirements from gossip are **Reliability**, 
there are sufficiently many persisted copies of delivered messages to guarantee availability against a threshold of failures. **Causality**, messages are delivered carrying information that reflects their ``happens-before'' causality order. **Integrity**, a message sent by an honest party is eventually delivered.

By separating the task of reliably disseminating transactions, 
DAG-based BFT consensus can be made highly efficient due to several considerations.

* A message dissemination substrate which is designed outside the consensus critical path can be made
highly efficient because it can regulate communication
based on network. 
* A DAG can continue growing even when consensus slows down, e.g., when a leader is faulty.
* A good gossip construction may outlive the consensus protocol for
which it is originally set up for, allowing improvements
in BFT consensus to be incorporated into existing systems without requiring to change their foundations.
* Vice versa, a networking substrate may evolve without risk to hurt the subtle logic of BFT
consensus solutions that use it.
* Consensus messages are made smaller because consensus needs to handle meta-info only. 

There is a very efective way to spread msgs reliably while incorporating causality meta-information.

Every message carries the following Fields:
- r - a round number
-
- self-cert - a certificate carrying 267
=

signatures from processes storing a
copy of the payload
- causal predecessors - reference to 2ft) hound
# messages.
The Mss also carries;
- payload - message contents that has utility,
=
such as transaction requests
We remark that self-certificates can be tlticiently
collected in "pull" mode, simultaneously obtaining
new messages from parties and aek's to own message.
The mempool protocol creates a global Dna structure;.

## BFT consensus inside the DAG 

Here, we describe an extremely simple in-DAG protocol which is based on PBFT, that has one layer commit rule.
We call it Fin, a small part of a Bullshark's tail.

Fin protocol rounds correspond to Dna tags 1- 1.

In round r, each party including a pre-determined
leader, collects 2F+1 or more references to round-(r-1) msgs.

* The pre-determined leader emits a proposal carrying refs.
* Non-leader parties wait for the leader proposal
for a round -timer RT.
* if a legitimate proposal is received,
apart-yÑtamsgcar_rying
- a ref to leader proposal at round r
- 26-11 ref's to round-(r-1) msgs
- a payload with new tx's
* if a timer expires, the party emits the
same as above but with no
leander proposal ref. This implicitly indicates
a fault/timeout report by the party.
* At any point when a round has 21--11 ref's
to a leader proposal <the proposal itself counts as
one), the proposal and its entire causal history
becomes committed

A leader proposal is legitimate if
* it is well formatted and signed
* like any Msg, It carries 2ft ref's to previous
round and Karrie s a self-certification
safety follows because if a round r proposal
=
becomes committed, then it. is in the canst
past of 2ft parties, of which 5-+1 are included
in any future proposal
after GST
Lire ness is guarantee#É honest players
😐a round g whose leader is good
at most RT-s ahead of the lender.
This should be the case if RT> 2s by the
properties of reliable broadcast

## Pure-DAG Solutions

In a pure DAG-rider solution, parties passively analyze the DAG structure and autonomously arrive at commit ordering decisions. 
No extra messages are exchanged by the consensus protocol nor is it given an opportunity to inject information into the DAG or control message emission. 
Total and Hashgraph's whitepaper algorithm are pure DAG-rider solutions. Both use randomization to solve consensus and both are rather theoretical and may suffer prohibitive latencies.


