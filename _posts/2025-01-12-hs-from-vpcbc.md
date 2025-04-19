---
title: 'From Quorum Certified (QC) Broadcast to HotStuff and HotStuff-2'
date: 2025-01-12 00:00:00 -07:00
permalink: "/posts/2025/01/hs-from-vpcbc/"
tags:
- Consensus
header:
  teaser: "/images/NY-3FPLUS1.jpeg"
  overlay_image: "/images/NY-3FPLUS1.jpeg"
  overlay_filter: rgba(0, 100, 100, 0.8)
excerpt: A modular construction
category:
- tutorial
---

# From Quorum Certified (QC) Broadcast to HotStuff and HotStuff-2

In this post, we give a simple and modular construction of both [HotStuff  by Yin, Malkhi, Reiter, Abraham and Gueta](https://api.semanticscholar.org/CorpusID:197644531), 
and [HotStuff-2 by Malkhi and Nayak](https://api.semanticscholar.org/CorpusID:259144145).

The construction [^1] consists of two parts.
First, a leader uses [*Quorum Certified (QC) Broadcast*](https://malkhi.com/posts/2025/01/vpcbc/) to post a new proposal. If it commits, it is guaranteed that $n-f$ Validators hold a lock on it. 
Second, a new leader starts with a simplified and linear sub-protocol which is enabled by a **Handover rule** . In a nutshell, the Handover rule guarantees that when leaders start a new view, they learn the latest QC which is locked by any Honest Validator. 


The difference between HotStuff and HotStuff-2 is utilizing 3 QC-phases in [``HotStuff: Three-Chain Rules''](https://malkhi.com/posts/2019/08/hotstuff-three-chain-rules/) and 2 QC-phases in
[HotStuff-2](https://malkhi.com/posts/2023/03/hs2/).
The (linear) implementation of the Handover rule for the two different cases is described in a separate post on the [Handover rule](https://malkhi.com/posts/2025/01/handover/).

## The Construction 

Like most protocols in [Partial Synchrony](https://malkhi.com/posts/2025/01/models/),
HotStuff/HotStuff-2 works in a view-by-view manner. 
Validators move from view to view, each view trying to commit a new transaction to the global chain.
In each view, one Validator is known as *leader*. 

Each view performs the following steps:

---

```
1. Handover. 

The leader waits for completion of the Handover condition in order to learn the highest QC held by Validators.

2. Quorum Certified (QC) Broadcast. 

The leader chooses a new transaction (or a batch) T extending the highest known QC and invokes QC-send(T).
Quorum Certified Broadcast disseminates a value with an External Validity predicate V(), such that if an Honest Validator QC-deliver(x), then: 

  (i) V(x) is satisfied.
  
  (ii) n-f Validators become locked on QC(x). 

Throughout the protocol, Validators maintain a lock on the highest QC they learn. 
The External Validity condition V() employed within QC Broadcast verifies that the leader proposal proposal extends the known lock or a higher one. 

Upon QC-deliver(T), a Validator commits T.

3. View Synchronization. 

Either upon a commit or if a commit doesn't happen within a certain period, send lock to the next leader and synchronize entry to the next view via Pacemaker sub-protocol for [View Synchronization](https://malkhi.com/posts/2023/04/lumiere/).
View Synchronization guarantees after GST that all Validators enter a view within a known bounded skew.

```
---

That's all!

Since QC broadcast incurs only linear Communication complexity, the crux is linearizing the leader handover regime. The goal of a leader handover is to guarantee that Validators accept leader proposals, in order to maintain progress.
The crux of the handover is for the next leader to learn whether it is possible for $2f+1$ to have a lock.
For many years, handover was handled via an approach pioneered in PBFT:


> [PBFT](https://api.semanticscholar.org/CorpusID:221599614) and [Tendermint](https://api.semanticscholar.org/CorpusID:59082906) achieved this goal via gossip communication: all Validators must receive exactly the same messages that the leader received and apply the same justification logic to accept the leader proposal. This requires quadratic word-Communication.
> Faced with a cascade of failures, this incurs super-quadratic (up to cubic) communication
    complexity which is sub-optimal.

HotStuff pioneered a different approach, which allowed a linear implementation in the Partial Synchrony setting.
The gist of the new approach is encapsulated by the following handover rule:

>**The Handover rule:** When a leader starts a new view, it must learn the latest lock which is held by any Honest Validator. Validators will accept a leader proposal conditioned on it extending the highest lock they know.

We dedicate a separate post to the [Handover rule](http://malkhi.com/posts/2025/01/handover/) and show how it can be materialized with linear word-Communication with either 2 QC-sphase or 3 QC-phases and under different setting.   
Note that the difference between HotStuff and HotStuff-2 is simply whether 2 or 3 QC-phases are used for disseminating the leader proposal. However, the two regimes require different implementations of the Handover rule. 

---
---

We now exemplify the effect of the Handover rule--regardless how it is materialized--through several scenarios.

**Scenario 1.** The figure below depicts two simple scenario.
On the left, views 1, 2, 3 are all successful operating QC to completion (denoted in green), and proposals $T1$, $T2$, $T3$ are chained to each other.

In the right, the QC in view 1 is not completed (shown as black), but it is "partially" successful: it generates and disseminates $QC(T1)$ to some Validators who become locked on it. Other Validators expire the view without accepting $QC(T1)$.

In the scenario below, despite QC only partially completing in View 1, 
the leader of view 2 learns $QC(T1)$ from View 1. Therefore, the leader proposal of View 2 extends $QC(T1)$ with $T2$. All Honest parties accept the proposal, and View 2 is successful in completing QC. Transaction $T2$ is committed (shown in green), and $T1$ is indirectly committed by being extended by $T2$. View 3 extends $T2$ normally.

![image](/images/HS/chain-ab.png)

---

What happens if a leader does not learn any QC from the immediately preceding view?

**Scenario 2.**
Consider the case above, i.e., the leader of view 1 does not succeed in completing QC, and that the leader of View 2 makes a proposal $T2$ that does not extend $QC(T1)$.

If there are no Validators locked on $QC(T1)$ (shown on left), Validators accept the proposal and vote for $T2$. Hence, View 2 is successful in completing QC, Transaction $T2$ is committed (shown in green), and $T1$ is **abadoned**. View 3 extends $T2$ normally.

On the right, the scenario shows what happens if Validators are locked on $QC(T1)$ but the leader of View 2 does not learn the highest lock. In this case, the proposal $T2$ in View does not extend the highest lock, hence the QC by the leader of View 2 may not succeed.
In View 3, the leader proposes to extend $QC(T1)$, and View 3 is successful (shown in green). $T1$ and $T3$ become committed, where $T1$ is indirectly committed by being extended by $T3$. Transaction $T2$ is **abandoned**.
The Handover rule prevents what happened to View 2 from happening to Honest leaders.

![image](/images/HS/chain-cd.png)

---

[^1]: The variants of HotStuff we look at here are not pipelined; we will comment in a future post on pipelining QC. 


