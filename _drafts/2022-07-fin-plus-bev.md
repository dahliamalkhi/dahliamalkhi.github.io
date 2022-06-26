---
title: 'DAG-BFT with BEV-resistant Fair-Ordering'
date: 2022-07-01
permalink: /posts/2022/07/dag-fo/
header: 
  teaser: "/images/FIN/SWARMING-animate-2.gif"
tags:
  - blockchain
  - DAG
  - Consensus
  - BEV
  - Fair ordering
  - BFT
---

<img src="/images/FIN/SWARMING-animate-2.gif" />

In a [previous post](..), we explained the use of a reliable, causally-ordered broadcast DAG transport 
in constructing message-free BFT consensus.

## Fair Ordering

We can build fair ordering into DAG-based BFT Consensus protocols
in order to prevent blockchain extractable value (BEV) exploits.
** add: why is BEV a serious problem**.
BEV is a measure introduced by Daian et al. in
[Flash Boys 2.0](https://ieeexplore.ieee.org/document/9152675)
of the "profit that can be made through including, excluding, or re-ordering transactions within blocks". 
It is related to and replaces a previously coined measure called maximal extractable value (MEV).
Heimbach and Wattenhoffer define 
in [SoK on Preventing Transaction Reordering](https://arxiv.org/pdf/2203.11520.pdf)
a transaction ordering as _fair_ "when it is not possible
for any party to include or exclude transactions after seeing their
contents. Further, it should not be possible for any party to insert
their own transaction before any transaction whose contents it
already been observed." 
Section 5.5 in the SoK mentions 
other forms of fairness in algorithmic committee orderings, e.g., 
[Fairledger](),
[DAG-Rider](),
[Tusk](),
[Bullshark]().
These systems address a different notion of fairness that guarantees, in its weak form, censorship-resistance 
and, in its stronger form, certain participation equality.
Neither of these provides BEV mitigation, a corrupt leader might reorder transactions it has already observed.
Unfortunately, the literature uses the same term, fairness ordering, for different notions. 

Here, we are interested in ordering fairness to protect against BEV. 
Heimach and Wattenhoffer define fairness around a notion of non-observability that we will name Blind-Order Fairness:

* “Blind-Order Fairness” [SoK on Preventing Transaction Reordering, 2022](https://arxiv.org/pdf/2203.11520.pdf)
   * It is not possible for a party to see a transaction and include or exclude transcations based on its content.

There are various other forms of ordering fairness pursued in the literature, including: 

* “Batch-Order Fairness” [Aequitos, Crypto 2020](https://eprint.iacr.org/2020/269.pdf), [Themis, ??](https://eprint.iacr.org/2021/1465.pdf).
   * If sufficiently many (at least ½ of the) nodes receive a transaction tx before another transaction tx0, then no honest node can deliver tx in a block after tx0
* “Approximate-Order Fairness”  [Aequitos, Crypto 2020](https://eprint.iacr.org/2020/269.pdf)
   * If sufficiently many nodes receive a transaction tx more than a pre-determined gap before another transaction tx0, then no honest node can deliver tx0 before tx.
   * Provable impossible to achieve under Condorcet scenarios, but in practice, holds in most fairness-sequencing protocol executions.
* “Differential-order fairness” [Quick Order Fairness](https://arxiv.org/pdf/2112.06615.pdf) 
   * When the number of correct processes that broadcast tx before tx0 exceeds the number that broadcast tx0 before tx by more than 2f + κ, for some κ ≥ 0, then the protocol must not deliver tx0 before tx (but they may be delivered together).
* “Ordering Linearizability” [Pompe, OSDI 2020](https://www.usenix.org/conference/osdi20/presentation/zhang-yunhao)
   * Clock based
   * If all correct players timestamp transactions tx, tx’ such that tx’ has a lower timestamp than tx by everyone, then tx’ is ordered before tx. 
* “Timed Relative Fairness” [Wendy, FC 2021 & AFT 2020](..)
   * If there is a time t such that all honest parties saw (according to their local clock) tx before t and tx0 after t , then tx must be scheduled before tx0.

## Blind Ordering

The first line of defense against BEV non-observability is
to keep transaction information hidden until after a commit is delivered on a "blind" ordering. 
This prevents any party from observing the contents of transactions until the ordering has been committed, hence satisfies Blind-Ordering Fairness.

To order transactions blindly, 
users broadcast encrypted transactions to the Consensus parties, 
such that decrypting a transaction requires a threshold greater than F of the parties to participate. 
Parties must contribute to decrypting a transaction only after observing the transaction committed in the DAG.

One way to implement this is using pub/private key encryption, 
such that the public key is known to users and the private key is shared (at setup time) among parties.
Another way is for users to encrypt each transaction with a symmetric key chosen for it, 
and share the key among parties using Shamir's secret sharing scheme.

The two forms differ in the manner in which the integrity of shares collected from parties can be verified:

* Public key encryption schemes allow to verify that a party is contributing a correct decryption share and furthermore, 
a threshold of honest parties can always succeed in decrypting. 
Parties can send the decryption shares in messages outside the DAG protocol or piggyback them on normal DAG broadcasts (as depicted below). 

* In the secret-sharing scheme, a bad user might send bogus shares to some parties.
Hence, reconstructing the key from different subsets of parties might produce different keys. 
Using a verifiable secret-sharing scheme (VSS), a user can prove to parties that the shares they receive
are valid and have a unique reconstruction.
VSS can be implemented inside the asynchronous echo broadcast protocol, e.g., 
employing a scheme by Basu et al. for 
[Efficient VSS in BFT Protocols](https://dahliamalkhi.github.io/files/T3P-CCS19.pdf).

Both methods above have non-neglible complexity. 
Luckily, we can leverage the DAG structure to simplify Blind-Ordering, 
foregoing secret-sharing verification completely. 

The idea is that when a DAG commit is observed, it is regarded as _provisional_ only. 
When a party observes that a transaction is provisionally committed, it broadcasts
its share of the decryption key for the transaction.
Note that key shares do not need dedicated broadcasts, they can be piggybacked on the stream of normal broadcasts. 

Only after the leader of the next view has delivered F+1 messages with shares, 
it enters the view (by setting setInfo() to the next view number).
In this way, the next view proposal references F+1 shares of provisional commits from the previous view.
When the proposal commits,
every provisional transaction in its causal past has F+1 shares and
anyone can decrypt it.
[Figure 1](#Figure-SS1) below depicts three views with proposals enabled by exposing F+1 in the preceding view.

  <span id="Figure-SS1"></span>

  <img src="/images/FIN/share-expose-1.png" width="750"  class="center"  />

  **_Figure 1:_** 
  _Exposing shares in views r and r+1 enable next view proposals._ 

This method guarantees agreement about how to decrypt (or about failing to decrypt) committed transactions.
Note that when more than F+1 shares are broadcast, the leader has a choice which ones to reference. 
This is fine because if the user is honest, all compositions are the same; and if not, we don't care what the leader chooses.

Importantly, 
in all the above cases, blind ordering do not send extra messages nor require the DAG to wait for Consensus steps. 

## Other requirements
