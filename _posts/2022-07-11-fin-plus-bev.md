---
title: 'Another Advantage of DAG-based BFT: BEV Resistance'
date: 2022-07-11
permalink: "/posts/2022/07/dag-fo/"
header:
  teaser: "/images/share-expose-1.png"
tags:
  - blockchain
  - DAG
  - Consensus
  - BEV
  - Fair ordering
  - BFT
---

Authors: Dahlia Malkhi and Pawel Szalachowski.

<img src="/images/FIN/SWARMING-animate-2.gif" />

## Synopsis

Another advantage of a [DAG-based approach to BFT Consensus](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/)
is enabling simple and smooth prevention of 
[blockchain extractable value (BEV) exploits](https://arxiv.org/pdf/1904.05234.pdf).
This post describes how to integrate "Order-Fairness"
into DAG-based BFT Consensus protocols to prevent BEV exploits.

The first line of BEV defense is ["Blind Order-Fairness"](https://arxiv.org/pdf/2203.11520.pdf).
The idea is for users to send their transactions to Consensus parties encrypted,
such that honest parties must be included to open the decryption key. 
Consensus parties commit to a blind order of transactions first, and only later open the transactions.
We discuss how to leverage the DAG structure to achieve blind ordering BEV protection in a simple and efficient manner.
Notably, 
the scheme operates without materially modifying the DAG's underlying transport,
without secret share verification, and in the happy path, it works in microseconds latency and avoids threshold encryption.

A deeper line of defense, 
["Time-Based Order-Fairness"](https://eprint.iacr.org/2020/269.pdf),
incorporates additional input on relative-ordering among batches of committed transactions. 
We discuss building such considerations into our scheme. 

The third line of defense is "Participation Fairness" (aka "Chain Quality"), 
which guarantees that a chain of blocks includes a certain portion of honest contributions.
As demonstrated in several previous systems, 
a "layered DAG" achieves certain participation equity for free, 
since at least a fraction of honest Consensus parties contributes in each layer.

<span id="BEV"> </span>
## Introduction: BEV and Order-Fairness

Over the last few years, we have seen exploding interest in cryptocurrency
platforms and applications built upon them, like decentralized finance protocols
offering censorship-resistant and open access to financial instruments; or
non-fungible tokens.
Many of these systems are vulnerable to BEV attacks, where a malicious consensus
leader can inject transactions or change the order of user transactions to maximize its
profit. Thus it is not surprising that at the same time we have witnessed
rising phenomena of BEV professionalization, where an entire ecosystem of BEV
exploitation, comprising of BEV opportunity "searchers" and collaborating
miners, has arisen.

BEV is a measure introduced by Daian et al. in
[[Flash Boys 2.0, S&P 2020]](https://arxiv.org/pdf/1904.05234.pdf)
of the _"profit that can be made through including, excluding, or re-ordering transactions within blocks"_.
It is related to and replaces a previously coined measure called miner/maximal extractable value (MEV).
[[MEV-explore]](https://explore.flashbots.net/) estimates the amount of BEV
extracted on Ethereum since the 1st of Jan 2020 to be close to $700M. However,
it is safe to assume that the total BEV extracted is much higher, since
MEV-explore limits its estimates to only one blockchain, a few protocols, and a
limited number of detectable BEV techniques.  Although it is difficult to argue
that all BEV is "bad" (e.g., market arbitrage can remove market inefficiencies),
it usually introduces some negative externalities like:

- Network congestion: especially on low-cost chains, BEV actors often try to
  increase their chances of exploiting a BEV opportunity by sending a lot of
  redundant transactions, spamming the underlying peer-to-peer network,
- Chain congestion: many such transactions finally make it to the chain, making
  the chain more congested,
- Higher blockchain costs: while competing for profitable BEV opportunities, BEV
  actors bid higher gas prices to prioritize their transactions, which results in
  overall higher blockchain costs for regular users,
- Consensus stability: some on-chain transactions can create such a lucrative BEV
  opportunity that it may be tempting for miner(s) to create an alternative
  chain fork with such a transaction extracted by them, which
  introduces consensus instability risks.

In this blog post, we focus on consensus-level BEV mitigation techniques.
There are fundamentally two types of BEV-resistant Order-Fairness properties:

**Blind Order-Fairness.**
A principal line of defense against BEV
stems from committing to transaction ordering without seeing transaction contents.
This notion of BEV resistance, referred to here as Blind Order-Fairness,
is used by Heimbach and Wattenhoffer
in [[SoK on Preventing Transaction Reordering, 2022]](https://arxiv.org/pdf/2203.11520.pdf)
and is defined as

>  "when it is not possible for any party to include or exclude transactions
>  after seeing their contents. Further, it should not be possible for any party
>  to insert their own transaction before any transaction whose contents it
>  already been observed."

**Time-Based Order-Fairness.**
Another strong measure for BEV protection is brought by sending transactions to all Consensus parties simultaneously and using
the relative arrival order at a majority of the parties to determine the final ordering.
In particular, this notion of order fairness ensures that

> "if sufficiently many parties receive a
> transaction tx before another tx', then in the final commit order tx' is not sequenced before tx."

This prevents powerful adversaries that can analyze network traffic and
transaction contents from reordering, censoring, and front-/back-running
transactions received by Consensus parties. Moreover, Time-Based Order-Fairness has stronger protection against a potential collusion between users and Consensus leader/parties because parties explicitly input relative ordering into the protocol.

Time-Based Order-Fairness is used in various flavors in several recent works, including
[[Aequitas, CRYPTO 2020]](https://eprint.iacr.org/2020/269.pdf),
[[Pompē, OSDI 2020]](https://www.usenix.org/system/files/osdi20-zhang_yunhao_0.pdf),
[[Themis, 2021]](https://eprint.iacr.org/2021/1465.pdf),
[Wendy Grows Up [FC 2021]](https://link.springer.com/chapter/10.1007/978-3-662-63958-0_17) and
[[Quick Order Fairness, FC 2022]](https://fc22.ifca.ai/preproceedings/136.pdf),
We briefly discuss some of those protocols later in the post.

Another notion of fairness found in the literature, that does not provide Order-Fairness, 
revolves around participation fairness:

**Participation Fairness.**
A different notion of fairness aims to ensure 
censorship-resistance or stronger notions of participation equity.
Participation equity guarantees that a chain of blocks includes a certain portion of honest contribution (aka "Chain Quality").
Several BFT protocols address Participation Fairness, including
[[Prime, IEEE TDSC 2010]](https://ieeexplore.ieee.org/document/5654509),
[[Fairledger, 2019]](https://arxiv.org/pdf/1906.03819.pdf),
[[HoneyBadger, CCS 2016]](https://eprint.iacr.org/2016/199.pdf), and many others. 
In layered DAG-based BFT protocols like 
[[Aleph, AFT 2019]](https://arxiv.org/pdf/1908.05156.pdf),
[[DAG-Rider, PODC 2021]](https://arxiv.org/pdf/2102.08325.pdf),
[[Tusk, 2021]](https://arxiv.org/abs/2105.11827),
[[Bullshark, 2022]](https://arxiv.org/pdf/2201.05677.pdf),
Participation Fairness comes essentially for free because every DAG layer must include messages from 2F+1 participants.
It is worth noting that participation equity does not prevent 
a corrupt party from injecting transactions after it has already observed other transactions,
nor a corrupt leader from reordering transactions after reading them,
violating both Blind and Time-Based Order-Fairness.

## Outline

We proceed to describe how to build Order-Fairness into DAG-based BFT Consensus for the partial synchrony model,
focusing on preventing BEV exploits.
The rest of this post is organized as follows:

* The next section provides a [**Quick refresher on DAG-based BFT Consensus and Fin**](#quick-referesher);
We refer the reader to a 
[previous post on DAG-based BFT Consensus and Fin](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/) for further details, 
and to a list at its bottom for 
[further reading on DAG-based BFT Consensus](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/#DAG-Reading).

* Following is a section that discusses [**Order-then-Reveal: On Achieving Blind Order-Fairness**](#Order-then-Reveal).
It contains two strawman "order-commit first, reveal later" implementations, 
[Order-then-Reveal with Threshold Cryptography](#strawman1),
[Order-then-Reveal with Verifiable Secret-Sharing (VSS)](#strawman2).

* It is followed by the introduction of [**Fino: Optimistically-Fast Blind Order-Fairness without VSS**](#Fino). 
Fino achieves the best of both worlds, seamless blind ordering of threshold cryptography with the low latency of secret sharing.

* The next section reports [**Threshold Encryption vs Secret Sharing**](#performance) micro-benchmarks. 

* The last section adds a discussion on [**Achieving Time-Based Order-Fairness**](#time-based).

<span id="quick-refresher"> </span>
## Quick refresher on DAG-based BFT Consensus and Fin

[DAG-based BFT Consensus](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/)
revolves around a broadcast transport that
guarantees message Reliability, Availability, Integrity, and Causality.

In a DAG-based BFT Consensus protocol,
a party packs transaction digests into a block,
adds references to previously _delivered_ (defined below) messages,
and broadcasts a message carrying the block and the causal references to all parties.
When another party receives the message, it checks whether it needs to retrieve
a copy of any of the transactions in the block and in causally preceding blocks.
Once it receives a copy of all transactions in the causal past of a block it can acknowledge it.
When 2F+1 acknowledgments are gathered, the message is "delivered" into the DAG. 

One implementation of reliable broadcast is due to [[Bracha, 1987]](https://core.ac.uk/download/pdf/82523202.pdf).
Each party sends an *echo* message upon receiving a new transaction.
Each party, after receiving 2F+1 echoes (or F+1 ready votes), can issue and broadcast a
*ready vote*.  A party delivers the transaction when 2F+1 ready votes are received.
Another implementation used in several earlier systems, e.g., 
[[Reiter and Birman, 1994]](https://dl.acm.org/doi/pdf/10.1145/177492.177745) and
[[Cachin et al., 2001]](https://link.springer.com/content/pdf/10.1007/3-540-44647-8_31.pdf),
employs threshold cryptography.

Several recent systems, e.g.,
[Aleph](https://arxiv.org/pdf/1908.05156.pdf),
[Narwhal-HS](https://arxiv.org/abs/2105.11827),
[DAG-Rider](https://arxiv.org/abs/2102.08325),
[Tusk](https://arxiv.org/abs/2105.11827), and
[Bullshark](https://arxiv.org/abs/2201.05677),
construct DAG transports in a layered manner, 
demonstrated excellent network utilization and throughput. 
In a layered DAG, 
each party can broadcast one message in each layer carrying 2F+1 references to messages in the preceding layer. 
We note that layering is not required for any of the methods described below
but has important benefits on performance and Participation Fairness.

Given the strong guarantees of a DAG transport,
Consensus can be embedded in the DAG quite simply, for example, using [[Fin, 2022]](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/). Briefly, Fin works as follows:

* **Views.** The protocol operates in a view-by-view manner. Each view is numbered, as in "view(r)", and has a designated leader known to everyone.

* **Proposing.** 
When a leader enters a new view(r), it sets a "meta-information" field in its coming broadcast to `r`. 
A leader's message carrying `r` (for the first time) is interpreted as `proposal(r)`. 
Implicitly, `proposal(r)` suggests to commit to the global ordering of transactions all the blocks in the causal history of the proposal.

* **Voting.** When a party sees a valid leader proposal, it sets a "meta-information" field in its coming broadcast to `r`. 
A party's message carrying `r` (for the first time) following `proposal(r)` is interpreted as `vote(r)`. 


* **Committing.** Whenever a leader proposal gains F+1 valid votes, the proposal and its causal history become committed.

* **Complaining.**
If a party gives up waiting for a commit to happen in view(r), it sets a "meta-information" field in its coming broadcast to `-r`. 
A party's message carrying `-r` (for the first time) is interpreted as `complaint(r)`. 
Note, a message by a party carrying `r` that causally follows a `complaint(r)` by the party, if exists, is **not** interpreted as a vote.

* **View change.**
Whenever a commit occurs in view(r) or 2F+1 `complaint(r)` are obtained, the next view(r+1) is enabled.

We refer the reader to a 
[previous post on DAG-based BFT Consensus and Fin](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/) 
for further details,
and to a list at its bottom for [further reading on DAG-based BFT Consensus](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/#DAG-Reading).

<span id="Order-then-Reveal"> </span>
## Order-then-Reveal: On Achieving Blind Order-Fairness

The first line of defense against BEV is
to keep transaction information hidden until after a commit is delivered "blindly".
This prevents any party from observing the contents of transactions until the ordering has been committed,
hence satisfying Blind Order-Fairness.

To order transactions blindly,
users choose a symmetric key to encrypt each transaction and broadcast the transaction encrypted to Consensus parties.
Decrypting the transaction key ("tx-key") itself 
requires a threshold greater than F of the parties to participate.
Parties must withhold revealing decryption shares until after they observe the transaction's ordering committed.

The challenge with Blind Order-Fairness is that we want messages to enter the DAG encrypted
and guarantee that later, parties can uniquely decipher them. 
Hence, we need to add the following requirement to the DAG transport:

**Decipherability:** If `deliver(m)` happens at an honest party, i.e., `m` is delivered into the local DAG of an honest party,
then eventually `m` can be uniquely deciphered.

<span id="strawman1"> </span>
### Strawman 1: Order-then-Reveal with Threshold Cryptography

It is straight-forward to support blind ordering using threshold encryption,
such that a public encryption "E()" is known to users and the private decryption "D()" is shared (at setup time) among parties.

To order transactions tx blindly using threshold encryption,
a user first chooses a transaction-specific symmetric key tx-key and encrypts tx with it.
It sends tx encrypted with tx-key to the Consensus parties and attaches E(tx-key), 
the transaction key encrypted with the global threshold key.
Once a transaction tx's ordering is committed, 
every party immediately reveals its decryption share for D(tx-key),
piggybacked on the DAG broadcast that causally follows the commit.
Some threshold cryptography schemes allow to verify that a party is contributing a correct decryption share.
A threshold of honest parties can always succeed in decrypting messages,
hence Decipherability of a committed transaction is guaranteed as soon as F+1 honest messages causally follow the commit.

The main drawback of threshold cryptography is that share verification and decryption are computationally heavy.  It takes an order of milliseconds per transaction in today's computing technology, as we show later in the article
(see [Performance notes](#Performance)).

<span id="strawman2"> </span>
### Strawman 2: Order-then-Reveal with Verifiable Secret-Sharing (VSS)

Another way for users to share with Consensus parties transaction-specific symmetric keys tx-key 
is [[Shamir's secret sharing scheme, CACM 1979]](https://dl.acm.org/doi/pdf/10.1145/359168.359176).
A sharing function "SS-share(tx-key)" is employed by users to send individual shares to each Consensus party, 
such that F+1 parties can combine shares via "SS-combine()" to reconstruct tx-key.

Combining shares is three orders of magnitude faster than threshold crypto and takes a few microseconds in today's computing environment
(see [Performance notes](#Performance)).
The challenge in the secret sharing scheme is that a bad user might send bogus shares to some parties, or not send shares to some parties at all.
Furthermore, reconstructing the key from different subsets of parties might produce different keys.

Thus, it is far less straight-forward to build Decipherability via secret sharing on top of a DAG:

1. When a transaction ordering becomes committed, revealing F+1 shares is not guaranteed even during periods of synchrony.
In particular, there may be only F+1 honest parties with shares but F of them are "left behind" when the DAG grows.
Although unlikely, this situation could linger indefinitely simply due to the slowness of honest parties,
and there would be an insufficient number of shares in the DAG to decrypt the transaction. 
In each layer of a DAG, participation by 2F+1 parties is guaranteed, but unfortunately:
    - F of them could be bad and pretend they don't have shares, 
    - F of them do not have shares, 
    - Only one party out of F+1 honest parties that have shares participates and reveals its share. 

2. Conversely, if more than F+1 shares are revealed, combining different subsets could yield different "decryption" tx-keys
if the user is bad. Hence, a transaction decryption might not be uniquely determined.

**Decipherability with VSS.**
One solution is to employ a VSS scheme, allowing F+1 parties 
to construct missing shares on behalf of other parties, 
as well as to verify that shares are consistent, 
This enables the integration of secret sharing into the DAG broadcast protocol, but it requires modifying the DAG transport.

**A DAG transport with Secret Sharing.**
To ensure that a transaction that has been delivered into the DAG can be deciphered,
a party should not acknowledge a message 
unless it has retrieved its own individual shares for all the transactions referenced in the message and its causal past. 

For example, integrating VSS inside Bracha's reliable broadcast, 
when a party observes that it has missed a share for a transaction referenced in a message (or its causal past), 
it initiates VSS share recovery before sending a ready vote for the message. 
This guarantees that a fortiori, after blindly committing to an ordering for the transaction, 
messages from every honest party reveal shares for it.

The overall communication complexity incurred in VSS on the user sharing a secret and on a party recovering a share has dramatically improved in recent years:

* VSS can be implemented inside the asynchronous echo broadcast protocol in
n<sup>3</sup> communication complexity using
Pederson's original two-dimensional polynomial scheme
[[Non-Interactive Polynomial Commitments, CRYPTO 1991]](https://link.springer.com/chapter/10.1007/3-540-46766-1_9).
* Kate et al. introduced a VSS scheme with n<sup>2</sup> communication complexity
[[Constant-Size Polynomial Commitments, ASIACRYPT 2010]](https://www.iacr.org/archive/asiacrypt2010/6477178/6477178.pdf),
later utilized for AVSS
by Backes et al.
[[eAVSS-SC, CT-RSA 2013]](https://eprint.iacr.org/2012/619).
* Basu et al. improved to linear (n) communication complexity
[[T3P, CCS 2019]](https://dahliamalkhi.github.io/files/T3P-CCS19.pdf).

Despite the vast progress in VSS schemes, there remain a number of challenges.
The main hurdle is that when a message is delivered with 2F+1 acknowledgments,
parties may need to recover their individual shares when they reference it 
in order to satisfy the Reliability property of DAG broadcast.
As noted above, 
the most efficient VSS scheme requires linear communication and
each share carries linear size information for recovery.
Implementing VSS (e.g., due to Kate et al.) requires non-trivial cryptography.
Last, as noted above, in the DAG setting this requires integrating a share-recovery protocol in the underlying transport.

<span id="Fino"> </span>
## Fino: Optimistically-Fast Blind Order-Fairness without VSS

Can we have the best of both worlds, seamless Decipherability of threshold cryptography with the low latency of secret sharing?

Enter **Fino**,
an embedding of Blind Order-Fairness in DAG-based BFT Consensus
that leverages the DAG structure to completely forego the need for share verification,
users fast secret-sharing during steady-state,
and falls back to threshold crypto during a period of network instability.
That is, Fino works without VSS and is optimistically fast.
Importantly, in Fino the DAG transport does not need to be materially modified.

The key insight is to use the DAG structure to drive a unique SS-combining with zero overhead.
After a blind ordering decision is made in a view, a proposal in a succeeding view implicitly determines a unique decryption by those shares that have been revealed in its causal past.

To build Fino, we wanted a simple baseline DAG-BFT algorithmic foundation, so we chose
[[Fin, 2022]](https://dahliamalkhi.github.io/posts/2022/06/dag-bft/), hence the name
Fino -- **Fin** plus BEV-resistant **O**rder-Fairness.
The advantage is Fin's simplicity of exposition, the lack of rigid layer structure, and because in Fin messages can be inserted into the DAG
independently of Consensus steps or timers,
but Fino can possibly be built on other DAG-BFT systems.

An important feature of the DAG-based BFT approach, which Fino preserves while adding blind ordering, is zero message overhead.
Additionally, Fino never requires the DAG to wait for input that depends on Consensus steps/timers.

### Overview of Fino 

To order transactions tx blindly in Fino,
a user first chooses (as before) a transaction-specific symmetric key tx-key and encrypts tx with it.

Users share with Consensus parties transaction-specific symmetric keys tx-key twice.
First, they use SS-share(tx-key) and send parties individual shares of tx-key.
Second, as a fallback, they use E(tx-key) to encrypt tx-key with the global threshold public key.

Once a transaction tx's ordering is committed, every party that holds a share for tx-key reveals it 
piggybacked on the DAG broadcast that causally follows the decision.
A party that doesn't hold a share for tx-key reveals a threshold key decryption share, 
similarly piggybacked on a normal DAG broadcast that causally follows the commit.

It is left to form agreement on a unique decryption.
Luckily, we can embed deterministic agreement about how to decipher transactions into the DAG 
with zero extra messages and no waiting for Consensus steps/timers.
Parties simply interpret their local DAGs to arrive at unanimous deterministic decryption.

More specifically, views, proposals, votes, and complaints in Fino are the same as Fin.
The differences between Fino and Fin are as follows:

**Share revealing.**
When parties observe that a transaction tx becomes committed, their next 
DAG broadcast causally following the commit reveals shares of the decryption key tx-key in one of two forms:
a party that holds a share for SS-combine(tx-key) reveals it,
while a party that doesn't hold a share for SS-combine(tx-key) reveals a threshold share for D(tx-key).

**TX Opening.**
When a new leader enters view(r+1), it emits a proposal `proposal(r+1)` as usual.
However, when the proposal becomes committed,
it determines a unique decryption for every transaction `tx` in the causal past of `proposal(r+1)` that satisfies:

   * `tx` is committed but not yet opened, <br>
   * `tx` has F+1 certified shares revealed in the causal past of `proposal(r+1)`,

Note that above, `txt` could be from views earlier than view(r) if they haven't been opened already.

The commit rule ensures that when a transaction is opened, it has a unique decryption.
For example, a deterministic decryption rule may be:
decrypt transactions in commit order using SS-combine() shares, if existing, using the F+1 lowest parties whose certified revealed shares
are in the causal past. Otherwise, use any F+1 D() shares.
The deterministic selection of decryption shares guarantees that parties end up
with the same decrypted plaintext (note that a malicious client could send some
number of invalid shares, causing decryption inconsistency -- some node would
get a proper plaintext while some a pseudorandom string).
The rule also prevents other corner cases, like when bad parties reveal
shares from later transactions without revealing shares for already-ordered
ones.

**A note on Share Certification.**
In lieu of share verification information, in symmetric encryption,
a sender needs to certify shares so that parties cannot tamper with them.

A naive way would be for the sender to simply sign every share.
A better way is for the sender to combine all shares in a Merkle tree, certify the root, and send with
each share a proof of membership (i.e., a Merkle tree paths to the root);
then parties need to check only one signature when they collect shares for reconstruction.

### Scenario-by-scenario Walkthrough

**Happy-path scenario.**
[Figure 1](#Figure-SS1) below depicts a scenario with three views, r, r+1, and r+2.
Each view enables the next view via F+1 votes.
The scenario depicts `proposal(r+1)` becoming committed. The commit uniquely determines how to open transactions from `proposal(r)`,
whose shares have been revealed in the causal past of `proposal(r+1)`.
Differently, `proposal(r+2)` is sent before delivering F+1 shares of transactions from `proposal(r+1)`.  
Therefore, `proposal(r+2)` becomes committed without opening pending committed transactions from view(r+1).

  <span id="Figure-SS1"></span>

  <img src="/images/share-expose-1.png" width="750"  class="center"  />

  **_Figure 1:_**
  _Commits of `proposal(r)` and `proposal(r+1)`, followed by share revealing opening `proposal(r)` tx's._

**Scenario with a slow leader.**
A slightly more complex scenario occurs when a view expires because
parties do not observe a leader's proposal becoming committed and they broadcast complaints.
In this case, the next view is not enabled by F+1 votes but rather, by 2F+1 complaints.

When a leader enters the next view due to 2F+1 complaints, the proposal of the preceding view is not considered committed yet.
Only when the proposal of the new view becomes committed does it
indirectly cause the preceding proposal (if exists) to become committed as well.

[Figure 2](#Figure-SS2) below depicts three views, r, r+1, and r+2.
Entering view(r+1) is enabled by 2F+1 complaints about view(r).
When `proposal(r+1)` itself becomes committed, it indirectly commits `proposal(r)` as well.
Thereafter, 
parties reveal shares for all pending committed transactions, namely, those in both `proposal(r)` and `proposal(r+1)`.
Those shares are in the causal past of `proposal(r+2)`. 
Hence, when `proposal(r+2)` will commit, a unique opening will be induced.

  <span id="Figure-SS1"></span>

  <img src="/images/share-expose-2.png" width="750"  class="center"  />

  **_Figure 2:_**
  _A commit of `proposal(r+1)` causing an indirect commit of `proposal(r)`, followed by share revealing of both._


<span id="performance"> </span>
## Threshold Encryption vs Secret Sharing
Threshold encryption and secret sharing provide slightly different properties
when combined with a protocol like Fino.  
We have implemented both schemes and compared their performance.  For
secret sharing, we implemented the 
[[Shamir's scheme, CACM 1979]](https://dl.acm.org/doi/pdf/10.1145/359168.359176), 
while for threshold encryption we implemented a scheme by 
Shoup and Gennaro [[TDH2, EUROCRYPT 1998]](https://link.springer.com/content/pdf/10.1007/BFb0054113.pdf).
First, we investigated the computational overhead that these schemes introduce.
For the presentation, we selected the schemes with the most efficient
cryptographic primitives we had access to, i.e., the secret sharing scheme was
implemented using the 
[[Ed25519 curve, J Cryptogr Eng 2012]](https://link.springer.com/content/pdf/10.1007/s13389-012-0027-1.pdf), 
while TDH2 is using 
[[Ristretto255, 2020]](https://www.ietf.org/archive/id/draft-irtf-cfrg-ristretto255-00.html) 
as the underlying prime-order group.  Performance for both schemes is presented in the
setting where 6 shares out of 16 are required to recover the plaintext.

| Scheme   |`Encrypt`|`ShareGen`|`Verify` |`Decrypt`|
|----------|------:|------:|------:|------:|
|Threshold, TDH2-based|311.6μs|434.8μs|492.5μs|763.9μs|
|Secret-sharing | 52.7μs|   -   | 2.7μs | 3.5μs |

The results are presented in the table as obtained on an Apple M1 Pro. `Encrypt`
refers to the overhead on the client-side while `ShareGen` is the operation of
deriving a decryption share from the TDH2 ciphertext by each party (this
operation is absent in the SSS-based scheme).  In TDH2 `Verify` verifies whether
a decryption share matches the ciphertext, while in the SSS-based scheme it only
checks whether a share belongs to the tree aggregated by the Merkle root
attached by the client. `Decrypt` recovers the plaintext from the ciphertext and
the number of shares.  As demonstrated by these measurements, the SSS-based scheme is much more
efficient.  In our Consensus scenario, each party processing a TDH2 ciphertext
would call `ShareGen` once to derive its decryption share, `Verify` *k-1* times
to verify the threshold number of received shares, and `Decrypt` once to obtain
the plaintext.  Assuming *k=6*, the total computational overhead for a single
transaction would be around 3.7ms of the CPU time.  With the secret sharing
scheme, the party would also call `Verify` *k-1* times and `Decrypt` once, which
requires only 17μs of the CPU time.

Besides the higher performance overhead, TDH2 requires a trusted setup, but the
scheme also provides some advantages over secret sharing. For instance, with a TDH2
ciphertext sent only to a single party and the network will be able to recover the
plaintext. An SSS-based requires the client to send shares directly to multiple parties.
Meanwhile,
waiting for the network to receive shares for a transaction, 
the transaction occupies buffer space on parties' machines and would need
to be either expired by the parties (possibly violating liveness) or kept in the
state forever (possibly introducing a denial-of-service vector).  Moreover, SSS
requires a trusted channel between clients and parties, which is not required by
TDH2 itself.  Finally, as described in Fino, the subset of shares used for decrypting a transaction requires a consensus decision.

<span id="time-based"> </span>
## Achieving Time-Based Order-Fairness

Fino achieves Blind Order-Fairness by deterministically ordering encrypted
transactions and then, after the order is final, decrypting them.
The deterministic order can be enhanced by sophisticated ordering logic
present in other protocols.
In particular, Fino can be extended to provide Time-Based Fairness
additionally ensuring that the received transactions are not only unreadable by
parties, but also their relative order cannot be influenced by malicious parties.

For instance, [[Pompē, OSDI 2020]](https://www.usenix.org/conference/osdi20/presentation/zhang-yunhao)
proposes a property called "Ordering Linearizability":

> if all correct parties timestamp transactions tx, tx' such that tx' has a
> lower timestamp than tx by everyone, then tx' is ordered before tx.

It implements the property based on an observation that if parties
exchange transactions associated with their receiving timestamps, then for each
transaction its median timestamp, computed out of 2F+1 timestamps collected, is
between the minimum and maximum timestamps of honest parties.

Fino can be easily extended by the Linearizability property offered by Pompē and the final
protocol is similar to the Fino with Blind Order-Fairness (see above) with
only one modification. Namely,
every time a new batch of transactions becomes committed,
parties independently sort transactions by their aggregate (median) timestamps.

More generally, 
Fino can easily incorporate other Time-based Fairness ordering logic.
Note that in Fino, the ordering of transactions is determined on
encrypted transactions, but time ordering information should be open. 
The share revealing, share collection, and unique decryption following a committed ordering are the same as
presented previously. The final protocol offers much stronger properties
since it not only hides payloads of unordered transactions from parties,
but also prevents parties from reordering received transactions.

Other protocols providing Time-based Order-Fairness include [[Aequitas, CRYPTO
2020]](https://eprint.iacr.org/2020/269.pdf) which defines "Approximate-Order
Fairness":

> if sufficiently many parties receive a transaction tx more than a pre-determined
> gap before another transaction tx', then no honest party can deliver tx' before
> tx.

The authors prove that it is impossible to achieve this property under Condorcet
scenarios, although, in practice, it might hold in most fairness-sequencing
protocol executions.
Then, they propose a relaxed definition of "Batch-Order Fairness":

> if sufficiently many (at least ½ of the) parties receive a transaction tx before
> another transaction tx', then no honest party can deliver tx in a block after
> tx',

and a protocol achieving it.

[[Themis, 2021]](https://eprint.iacr.org/2021/1465.pdf) is a more efficient
protocol realizing "Batch-Order Fairness", where parties do not rely on timestamps
(as in Pompē) but only on their relative transaction orders reported.  Themis
can also be integrated with Fino, however, to make it compatible this design
requires some modifications to Fin's underlying DAG protocol. More
concretely, Themis assumes that the fraction of bad parties cannot be one quarter, i.e., F out of 4F+1. 
A leader makes a proposal based on 3F+1 out of 4F+1 transaction orderings (each
reported by a distinct party). Therefore, we would need to modify the DAG transport
so that parties references preceding messages from a quorum greater than three-quarters of the system (rather than two-thirds).
message.

Other forms of Time-Based Order-Fairness appear in other recent works, including
[Wendy Grows Up [FC 2021]](https://link.springer.com/chapter/10.1007/978-3-662-63958-0_17) 
which introduced "Timed Relative Fairness":

> if there is a time t such that all honest parties saw (according to their
> local clock) tx before t and tx' after t , then tx must be scheduled before
> tx'.

and 
[[Quick Order Fairness, FC 2022]](https://fc22.ifca.ai/preproceedings/136.pdf),
which defined "Differential-Order Fairness":

> when the number of correct parties that broadcast tx before tx' exceeds the
> number that broadcast tx' before tx by more than 2F + κ, for some κ ≥ 0, then
> the protocol must not deliver tx' before tx (but they may be delivered
> together),

#### Acknowledgements

*Many thanks to [Mahimna Kelkar](https://www.cs.cornell.edu/~mahimna/) and [Oded Naor](https://www.odednaor.work/home) for the comments that helped improve this post.*
