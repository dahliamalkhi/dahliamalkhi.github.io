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
is the only blockchain era, pure DAG-rider solution to our knowledge. 
It makes use of bits within messages as pseudo-random coin tosses in order to drive randomized Consensus.
All of the above pure DAG protocols are designed without regulating DAG layers, and without injecting external common coin-flips to cope with asynchrony. 
As a result, they are both quite complex and their convergence slow. 

Fin finds a sweet-spot: albeit not being a pure DAG-rider, it is a simple and fast DAG-based protocol, that injects values 
into the DAG in a non-intrusive manner.



