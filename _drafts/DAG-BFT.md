## Away with Monolithic BFT Consensus; Enter DAG-based BFT Consensus

To scale the BFT (Byzantine Fault Tolerant) Consensus core of blockchains,
prevailing wisdom is to separate between two responsibilities. 

* The first is a transport for reliably spreading yet-unconfirmed transactions.
It regulates communication and optimizes throughput, but it tracks only causal ordering in the form of a DAG (Direct Acyclic Graph).

* The second is forming a sequential commit ordering of transactions. 
It must solve BFT Consensus utilizing the transport DAG.

The advent of building Consensus over a DAG transport is that while solving BFT Consensus, parties spread messages that carry useful payloads (e.g., transactions). 
A BFT Consensus protocol can periodically commit batches from the DAG, incurring a tiny cost over the spreading of transactions. 
Moreover, parties can continue sending messages and the DAG keep growing even when Consensus is stalled, e.g., when a Consensus leader is faulty, 
and later commit the messages accumulated in the DAG. 

It is funny how the community made a full circle, from early distributed consensus systems to where we are today. 
I earned my PhD more than two decades ago for contributions to scaling reliable distributed systems, 
guided by and collaborating with pioneers of the field, including
[Ken Birman](https://www.linkedin.com/in/ken-birman-3661a0/), 
[Danny Dolev](https://www.linkedin.com/in/danny-dolev-723aa616/), 
[Rick Schlichting](https://www.linkedin.com/in/rick-schlichting-6519487a/), 
[Michael Melliar-Smith](https://engineering.ucsb.edu/people/p-michael-melliar-smith), 
[Louis Moser](https://engineering.ucsb.edu/people/louise-moser), 
[Robbert van Rennesse](https://www.linkedin.com/in/rvanren/), 
[Yair Amir](https://www.linkedin.com/in/yair-amir-61b58/), 
[Idit Keidar](https://www.linkedin.com/in/idit-keidar-9033287/).
Distributed middleware systems of that time, e.g., 
[Isis](https://dl.acm.org/doi/10.1145/37499.37515), 
[Psync](https://dl.acm.org/doi/10.1145/65000.65001), 
[Trans](https://ieeexplore.ieee.org/document/80121?tp=&signout=success), 
[Total](https://dl.acm.org/doi/10.1145/327164.327298)
and 
[Transis](https://ieeexplore.ieee.org/document/243613), 
were designed for high-throughput by building consensus over causal message ordering (!).
This topic was so much in the spotlight that during 1993-1994,
a debate over the _usefulness of CATOCS (causal and totally ordered communication)_ carried into
several publications of the ACM SIGOPS,
[[CATOCS]](https://dl.acm.org/doi/10.1145/173668.168623)
[[Response 1 to CATOCS]](https://dl.acm.org/doi/10.1145/164853.164859)
[[Response 2 to CATOCS]](https://dl.acm.org/doi/10.1145/164853.164858).

Recent interest in scaling blockchains is rekindling interest in this approach with emphasis on Byzantine fault tolerance, e.g., in 
DAG-based BFT protocols like
[Swirlds hashgraph](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf),
[Blockmania](https://arxiv.org/abs/1809.01620),
[Aleph](https://arxiv.org/pdf/1908.05156.pdf),
[Narwhal & Tusk](https://arxiv.org/abs/2105.11827),
[DAG-rider](https://arxiv.org/abs/2102.08325), and
[Bullshark](https://arxiv.org/abs/2201.05677").

In post 1/3, I will explain the notion of 
[**DAG Trans**]("/_Drafts/DAG-Trans.md"), a reliable, causal broadcast transport that shares a DAG among parties. 
In post 2/3, I will demonstrate the utility of DAG Trans through 
[**Fin**]("/_drafts/FIN.md"), 
quite possibly the simplest and the most efficient novel DAG-riding BFT Consensus solution for the partial synchrony model, 
which the research team at @Chainlink Labs will be developing. 
In post 3/3, 
I will finish with a note on 
[**DAG-riding**]("/_drafts/DAG-Riding.md"), 
BFT Consensus solutions that build on [**DAG Trans**]("/_drafts/DAG-Trans.md"). 

For further reading, visit [**DAG-Based BFT Consensus Reading list**]("/_drafts/DAG-Reading.md")
