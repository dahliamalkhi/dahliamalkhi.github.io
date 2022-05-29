## DAG Trans: A Reliable Causal Broadcast Transport

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


