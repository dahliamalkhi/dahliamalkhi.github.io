---
title: 'From VPCBC to HotStuff and HotStuff-2'
date: 2025-01-12 00:00:00 -07:00
permalink: "/posts/2025/01/hs-from-vpcbc/"
tags:
- Consensus
header:
  teaser: "/images/NY-3FPLUS1.png"
  overlay_image: "/images/NY-3FPLUS1.png"
  overlay_filter: rgba(0, 100, 100, 0.8)
excerpt: A modular construction
category:
- tutorial
---

# From VPCBC to HotStuff and HotStuff-2

In this post, we give a simple and modular construction of both [HotStuff](https://api.semanticscholar.org/CorpusID:197644531) and [HotStuff-2](https://api.semanticscholar.org/CorpusID:259144145)[^1]
from three common ingredients:

**Verifiable-Provable-Consistent-Broadcast [VPCBC](https://malkhi.com/posts/2025/01/vpcbc/) sub-protocol.**

: VPCBC($x$, $V$) disseminates a value $x$ with an External Validity predicate $V()$, such that if an Honest Validator VPCBC-deliver($x$), then: 

  (i) $V(x)$ is satisfied.
  
  (ii) $n-f$ Validators become locked on $QC(x)$. 

**Handover-Completion rule.** 

: The Handover-Completion rule determins when it is safe to transition views. The predicate guarantees that **when leaders start a new view, they learn the latest VPCBC lock which is held by any Honest Validator.** An (linear) implementation of the rule is described in [a future post](https://).

**Pacemaker sub-protocol for [View Synchronization](https://malkhi.com/posts/2023/04/lumiere/).**

: View Synchronization guarantees after GST that all Validators enter a view within a known bounded skew.


## The Construction 

HotStuff/HotStuff-2 works in a view-by-view manner. 
Validators move from view to view, each view trying to commit a new transaction to the global chain.
In each view, one Validator is known as *leader*. 

Each view performs the following steps:

---

```
1. Handover. 

The leader waits for the Handover-Completion predicate to be satisfied in order to learn the highest QC held by Validators from previous VPCBCs.

2. VPCBC. 

The leader chooses a new transaction (or a batch) T extending the highest known QC and invokes VPCBC-send(T). 

	Throughout the protocol, Validators maintain a lock on the highest QC they learn from VPCBC. 
The External Validity condition V() employed within VPCBC verifies that the leader proposal proposal extends the known lock or a higher one. 

	Upon VPCBC-deliver(T), commit T.

3. View Synchronization. 

Either upon a commit or if a commit doesn't happen within a certain period, send lock to the next leader and synchronize entry to the next view via Pacemaker.

```
---

That's all!

The difference between HotStuff and HotStuff-2 is simply whether 2 or 3 phases are used in VPCBC.
Since VPCBC incurs only linear Communication complexity, it is left to linearize the Handover-Completion regime. The goal of Handover-Completion is to guarantee that Validators accept leader proposals, in order to maintain progress.

> [PBFT](https://api.semanticscholar.org/CorpusID:221599614) and [Tendermint](https://api.semanticscholar.org/CorpusID:59082906) achieved this goal via gossip communication: all Validators must receive the same messages that the leader received and apply the same justification logic to accept the leader proposal. This requires quadratic word-Communication.

HotStuff pioneered a different Handover-Completion approach: 

>**when leaders start a new view, they learn the latest lock which is held by any Honest Validator and extend it.** 

In a future post, we show how Handover-Completion predicate can be implemented with linear word-Communication with either 2-phase or 3-phase VPCBC under different setting.   

---
---

We now exemplify the use of the Handover-Completion predicate through several scenarios.

**Scenario 1.** The figure below depicts a simple scenario, where views 1, 2, 3 are all successful operating VPCBC's to completion (denoted in green), and proposals $T1$, $T2$, $T3$ are chained to each other.

![chain-a](https://hackmd.io/_uploads/HJ-P6mxDkg.png)

---

What happens if a VPCBC does not complete? 

**Scenario 2.** The figure below depicts another simple scenario. The VPCBC in view 1 is not completed (shown as black), but it is "partially" successful: it generates and disseminates $QC(T1)$ to some Validators who become locked on it. Other Validators expire the view without accepting $QC(T1)$.

In the scenario below, despite VPCBC only partially completing in View 1, 
the leader of view 2 learns $QC(T1)$ from View 1. Therefore, the leader proposal of View 2 extends $QC(T1)$ with $T2$. All Honest parties accept the proposal, and View 2 is successful in completing VPCBC. Transaction $T2$ is committed (shown in green), and $T1$ is indirectly committed by being extended by $T2$. View 3 extends $T2$ normally.

![chain-b](https://hackmd.io/_uploads/HyLW-Ngwke.png)

---

What happens if a leader does not learn any QC from the immediately preceding view?

**Scenario 3.**
Consider the case above, i.e., the leader of view 1 does not succeed in completing VPCBC, and that the leader of View 2 makes a proposal $T2$ that does not extend $QC(T1)$.

If there are no Validators locked on $QC(T1)$ (shown on left), Validators accept the proposal and vote for $T2$. Hence, View 2 is successful in completing VPCBC, Transaction $T2$ is committed (shown in green), and $T1$ is **abadoned**. View 3 extends $T2$ normally.

On the right, the scenario shows what happens if Validators are locked on $QC(T1)$ but the leader of View 2 does not learn the highest lock. In this case, the proposal $T2$ in View does not extend the highest lock, hence the VPCBC by the leader of View 2 may not succeed.
In View 3, the leader proposes to extend $QC(T1)$, and View 3 is successful (shown in green). $T1$ and $T3$ become committed, where $T1$ is indirectly committed by being extended by $T3$. Transaction $T2$ is **abandoned**.

![chaincd](https://hackmd.io/_uploads/HJMdmYgvkx.png)

---

[^1] The variants of HotStuff we look at here are not pipelined; we will comment in a future post on pipelining VPCBC. 


