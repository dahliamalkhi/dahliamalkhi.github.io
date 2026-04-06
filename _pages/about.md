---
title: About me
permalink: "/about/"
excerpt: dahlia malkhi -- profile and a short bio 
author_profile: true
header:
  overlay_image: "/images/hotstuff-expresso-zm.jpeg"
  overlay_filter: rgba(100, 0, 100, 0.6)
#redirect_from:
#- "/about.html"
---

## Short Bio

Dr. Dahlia Malkhi is a Professor of Computer Science at the University of California, Santa Barbara, and head of the [Foundations of Financial Technology (Fftech) Research Lab](https://fiftech.cs.ucsb.edu/) (2024–). She is a leading expert in distributed systems, with a focus on reliability, security, blockchain technologies, and financial infrastructure.

Over a career spanning more than two decades, Dr. Malkhi has bridged foundational research with large-scale industrial systems through senior leadership roles across academia and industry. She previously served as Chief Technology Officer of the [Diem Association](https://www.diem.com/en-us/) and Lead Researcher at [Novi Financial](https://about.fb.com/news/2020/05/welcome-to-novi/) (2019–2022). Prior to that, she co-founded [VMware Research](https://octo.vmware.com/introduction-vrg/) and was a Principal Researcher at VMware (2014–2019). Earlier, she was a Partner Principal Researcher at Microsoft Research (2004–2014), a tenured Associate Professor at the Hebrew University of Jerusalem (1999–2007), and a Senior Researcher at AT&T Labs (1995–1999).

Dr. Malkhi’s research has produced over [200 publications](https://scholar.google.com/citations?user=A_VZ8N0AAAAJ&hl=en) and has had lasting impact on modern distributed computing. She is a co-inventor of [HotStuff](https://arxiv.org/abs/1803.05069), a foundational consensus protocol that underpins the [Diem blockchain core engine](https://developers.diem.com/docs/technical-papers/state-machine-replication-paper/) and the [Aptos blockchain core engine](https://aptos.dev/reference/glossary/#aptosbft), among others. Her contributions also include co-inventing [Flexible Paxos](https://arxiv.org/abs/1608.06696), which underlies systems such as [LogDevice](https://logdevice.io/docs/Consensus.html), creating [CorfuDB](https://github.com/CorfuDB/CorfuDB), a database-less storage system used in VMware’s NSX-T distributed control plane, co-founding [VMware Blockchain](https://research.vmware.com/projects/vmware-blockchain), and co-leading the [FairPlay project](https://www.cs.huji.ac.il/project/Fairplay/), one of the earliest practical implementations of secure multiparty computation.

In parallel with her academic work, Dr. Malkhi serves as a sought-after advisor across the blockchain and financial technology ecosystem. Her roles include serving on the [Coinbase Independent Advisory Board on Quantum Computing and Blockchain](https://www.coinbase.com/blog/coinbase-establishes-independent-advisory-board-on-quantum-computing-and-blockchain) (established 2026), academic advisor to [Chainlink Labs](https://chainlinklabs.com/) (2025–present) and former Distinguished Scientist (2023–2025), Distinguished Scientist at StableClear LTD (2025–present), and advisor to [SpaceComputer IO](https://spacecomputer.io/), [Lyquor Labs](https://lyquor.xyz/), [Nubit Thunderbolt](https://www.nubit.org/), and [Espresso Systems](https://www.espressosys.com/). She has also served on the advisory board of [Cryptoeconomic Systems](https://cryptoeconomicsystems.pubpub.org/) since 2019.

Dr. Malkhi is an ACM Fellow (2011) and recipient of numerous honors, including the [IEEE TCDP Outstanding Technical Achievement Award](https://tc.computer.org/tcdp/awardrecipients/) (2021). She has played a leading role in the research community, including serving on the ACM SIGOPS ATC Steering Committee (2026–present), chairing the [ACM Charles P. “Chuck” Thacker Breakthrough in Computing Award](https://awards.acm.org/thacker) (2025), and previously co-chairing the Simons Institute Advisory Board (2019–2022). She has also served as program chair for major conferences including [USENIX ATC 2019](https://www.usenix.org/conferences/byname/131), [LADIS 2012](http://ladisworkshop.org/), [Locality 2007](http://research.microsoft.com/en-us/um/people/moscitho/locality/), [PODC 2006](http://www.podc.org/podc2006/), [Locality 2005](http://www.mimuw.edu.pl/~disc2005/index.php?page=workshops), and [DISC 2002](http://www.disc-conference.org/disc2002/index.html).


# Technology Impact

## HotStuff at VMware 2016 and DiemBFT at Diem(Libra) 2019

Renewed interest in the Blockchain world on scaling and robustifying the long standing problem of
asynchronous Byzantine Fault Tolerant (BFT) Consensus. 

In 2016 when designing the blockchain infrastructure at VMware’s blockchain project, we observed that 
all BFT solutions contain quadratic voting steps. Why is this so bad? When
Byzantine consensus protocols were originally conceived, a typical target system
size was n=4 or n=7, tolerating one or two faults. But scaling BFT consensus to
n=2000 means that even on a ``good day'' when communication is timely and a
handful of failures occurs, quadratic steps require 4,000,000 messages. A
cascade of failures might bring the communication complexity to whopping
8,000,000,000 transmissions for a single consensus decision. No matter how good
the engineering and how we tweak and batch the system, these theoretical
measures are a roadblock for scalability. 

Around that time, tremendous innovation was occurring outside academic circles
by blockchain startups. Two of these caught our attention, Tendermint
and Casper. These protocols dramatically simplified the
view change mechanism by introducing a
synchronous delay when a leader starts. I observed that by adding one more phase
to Tendermint, we can maintain the advantage of simplicity while avoiding the
delay it introduced. 
The result is 
[HotStuff: BFT Consensus in the Lens of Blockchain](https://arxiv.org/abs/1803.05069), 
named after a cartoon character in the same family of Casper, the
first responsive BFT solution with a linear view-change.

Beyond improving communication complexity, HotStuff embodies a minimalist algorithmic framework that bridges between classical BFT solutions and the blockchain world; the entire protocol is captured in less than half a page of pseudo-code.
HotStuff became popular in the blockchain developer community not only due to
linearity, but (and perhaps mostly) due to its simplicity and developer-friendly design. 
Diem(Libra) adopted it to drive the blockchain infrastructure, as did (that we know of) Flow, Celo,
and Cypherium. 

## Flexible Paxos at VMware 2016

In the summer of 2016, I hosted a research intern named Heidi Howard from
Cambridge, UK. I told her about the CorfuDB protocol and encouraged her to think
about the performance benefit of separating the sequencer role from the rest of
the system. The result has been a stunning revelation we named 
[Flexible Paxos: Quorum Intersection Revisited.](https://arxiv.org/abs/1608.06696):

>*Each of the phases of Paxos may use non-intersecting quorums. Only quorums from
different phases are required to intersect. Majority quorums are not necessary
as intersection is required only across phases.*

Everyone in the field of distributed systems knows that quorums in Paxos must
intersect, so what gives? What Heidi observed is that Paxos, which lies at the
foundation of many production systems, is conservative. Within each of the
phases of Paxos, it is safe to use disjoint quorums and majority quorums are not
necessary. Since the second phase of Paxos (replication) is far more common than
the first phase (leader election), we can use Flexible Paxos to reduce the size
of commonly used second phase quorums. By no longer requiring replication
quorums to intersect, we have removed an important limit on scalability. Through
smart quorum construction and pragmatic system design, we enabled a new breed of
scalable, resilient and performant consensus algorithms. 
The algorithmic core of a production scale-out messaging bus at Facebook called
[LogDevice](https://logdevice.io/docs/Consensus.html) is based on it, 
as is 
[the more flexible paxos](http://ssougou.blogspot.com/2016/08/a-more-flexible-paxos.html)
 of YouTube's distributed MySQL backbone.
 

## CorfuDB at Microsoft 2012 and at VMware 2014

In 2012, [Phil Bernstein](https://en.wikipedia.org/wiki/Phil_Bernstein) approached me at Microsoft Research with the following
observation. RAM has grown cheap/large enough to hold a complete database index
in memory. Therefore, one can build a fully replicated transaction processing
engine by storing a database index completely in-memory, persisting index
modifications to a shared commit-log. 
His team prototyped an in-memory index called Hyder. 
The key enabler for this vision would be a reliable, high throughput distributed log, which
Phil wanted to stripe across an array of SSDs. 
Unfortunately (yet fotunate for me), the initial design of his distributed
commit-log was flawed. While fixing the design, I extracted a foundational
insight that motivated me to establish and lead the
[CorfuDB project](https://github.com/CorfuDB/CorfuDB).

[CorfuDB](https://dl.acm.org/doi/10.1145/2535930)
is a database-less database built around a global,
reliable, high-throughput distributed commit-log. The CorfuDB log serves as the
source of ground truth around which one builds distributed control-planes for
large clusters. 
The key paradigm underlying CorfuDB is the reliable log that operates at high
throughput. This was the foundational insight I have taken from Hyder. I built
the first CorfuDB PoC at Microsoft with OS license, and later drove it at VMware to
production.
At VMware, CorfuDB serves as the a distributed control-plane for
[NSX-T](https://shuttletitan.com/nsx-t/nsx-t-management-cluster-benefits-roles-ccp-sharding-and-failure-handling/),
a leading SDN product that has market volume of over \$1B. 
At Facebook, CorfuDB was re-engineered in
[Delos](https://engineering.fb.com/data-center-engineering/delos/), a control plane underlying a dynamic cluster storage backend system. 

You might wonder what happened to Phil's in-memory fully replicated DB. Several years later, it became the backbone of the SQL Azure cloud database.


## Fairplay at the Hebrew University of Jerusalem 2004

In 2004, Noam Nisan and I asked ourselves whether cryptographic primitives which
were considered completely impractical are actually becoming practical. With my 
PhD student Yaron Sella, we implemented the MPC protocol, while Noam supervised
his grad-students to implement a language that compiles into a binary circuit. 
The first fully implemented 
[Fairplay MPC platform](https://www.cs.huji.ac.il/project/Fairplay/)
was alive shortly after.
By 2008, the the millionaires problem, mini auctions, and other problems, could be solved over an
interconnect in seconds.
Since then,
the Fairplay source code has been downloaded by hundreds of academic groups, and has
sparked in the past
decade a wave of crypto-engineering projects which bring crypto theory into
practice, including heavy crypto methods like oblivious RAM, ZK proofs and PCP.

# [Academic descendants]({{ base_path }}/descendants/)
