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


