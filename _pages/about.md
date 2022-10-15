---
title: About me
permalink: "/about/"
excerpt: dahlia malkhi -- profile and a short bio 
author_profile: true
header:
  overlay_image: "/images/CA-3FPLUS1.jpg"
  overlay_filter: rgba(100, 0, 100, 0.8)
  caption: "photo credit: Ted Yin"
#redirect_from:
#- "/about.html"
---

# Short bio

Dr. Malkhi's [research](https://scholar.google.com/citations?user=A_VZ8N0AAAAJ&hl=en)
over two decades 
spans broad aspects of reliability and security of distributed systems, recently with focus on blockchains and advances in financial technology.

A select sample of contributions includes: 

* Co-inventor of [HotStuff](https://arxiv.org/abs/1803.05069) (driving the [Diem blockchain core engine](https://developers.diem.com/docs/technical-papers/state-machine-replication-paper/), the [Aptos blockchain core engine](https://aptos.dev/reference/glossary/#aptosbft) and other blockchains, 
* Co-founder and technical co-lead of [VMware blockchain](https://research.vmware.com/projects/vmware-blockchain),
* Co-inventor of [Flexible Paxos](https://arxiv.org/abs/1608.06696) (the technology behind [Log Device](https://logdevice.io/docs/Consensus.html)),
* Creator and tech lead of [CorfuDB](https://github.com/CorfuDB/CorfuDB) (a database-less database driving VMware’s NSX-T distributed control plane),
* Co-inventor of the [FairPlay project](https://www.cs.huji.ac.il/project/Fairplay/).

Presently, Malkhi serves as Chief Research Officer of [Chainlink Labs](https://chainlinklabs.com/) (since Q1/2022). From 2019 to 2022, Malkhi served three roles in the Diem(Libra) project: CTO at the [Diem Association](https://www.diem.com/en-us/), Lead Maintainer of the [Diem open-source project](https://github.com/diem/diem), and Lead Researcher at [Novi](https://about.fb.com/news/2020/05/welcome-to-novi/). In 2014, after the closing of the Microsoft Research Silicon Valley lab, Malkhi co-founded [VMware Research](https://octo.vmware.com/introduction-vrg/) and became a Principal Researcher at VMware until June 2019. Prior to that, Malkhi was a partner principal researcher (last rank) 
at Microsoft Research, 2004-2014; 
a tenured Associate Professor (last rank, promoted in 2005) of the Hebrew University of Jerusalem, 1999-2007;
and a senior researcher (last rank) at AT&T Labs, 1995-1999.

# Selected academic roles and distinctions:

-   [IEEE TCDP Outstanding Technical Achievement Award](https://tc.computer.org/tcdp/awardrecipients/), 2021.
-   Advisory board member of [Cryptoeconomic Systems](https://cryptoeconomicsystems.pubpub.org/), 2019-present.
-   Co-chair of the Simons Institute [Advisory Board](https://simons.berkeley.edu/people/advisory), 2019-2022.
-   ACM fellow, 2011.
-   Associate editor of the Distributed Computing Journal, 2002-2018.
-   Associate editor of IEEE Transactions on Dependable and Secure Computing (TDSC), 2014-2016.
-   IBM Faculty award recipient, 2003 and 2004.
-   German-Israeli Foundation (G.I.F.) Young Scientist career award, 2002.
-   Program chair for [Usenix ATC 2019](https://www.usenix.org/conferences/byname/131), [LADIS 2012](http://ladisworkshop.org/) , [Locality 2007](http://research.microsoft.com/en-us/um/people/moscitho/locality/), [PODC 2006](http://www.podc.org/podc2006/), [Locality 2005](http://www.mimuw.edu.pl/~disc2005/index.php?page=workshops) and [DISC 2002](http://www.disc-conference.org/disc2002/index.html).

# Technology Impact

For over two decades, my work has been straddling by choice between foundational and applied research. 
I published over 150 papers; recent ones are listed on my homepage, DBLP
keeps track of the rest.

I was fortunate to bring several scientific results into fruition within leading industrial platforms. 
Below, I tell the stories of four technologies I participated in creating.

## HotStuff and DiemBFT -- Co-Inventor and Technical Lead, at VMware 2016, Diem(Libra) 2019

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

## Flexible Paxos -- Co-inventor, at VMware 2016

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
 

## CorfuDB -- Initiator and Technical Lead, at Microsoft 2012 and VMware 2014

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


## Fairplay -- Co-Inventor at Hebrew University of Jerusalem, 2004

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

## [Academic descendants]({{ base_path }}/descendants/)
