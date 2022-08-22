---
title: Blockchain in the Lens of BFT
date: 2017-10-30 00:00:00 -07:00
permalink: "/posts/2017/10/bft-blockchain/"
tags:
- Blockchain
- Consensus
category:
- tutorial
---

In the early 2000’s, a group of activists advocating the wide-spread use of cryptography and privacy-enhancing technologies were engaging over the `cypherpunks’ mailing-list in an effort to create an anonymous, monitor-free digital cash. Step by step, they jointly built the ingredients that eventually led to the emergence of Bitcoin in 2009.

The story of the evolution of the BitCoin technology is fascinating, and harnesses deep ideas and methods from published academic works. Its incredible market cap (around $100B, as of this post’s date) reflects the public trust in the robustness and soundness of the technology, without any company or institution backing it.

At the core of Bitcoin is a method for reaching agreement on a shared chain of blocks where each block contains a sequence of transactions. This core is called the Blockchain. In many ways, the Blockchain is the most intriguing and innovative aspect of Bitcoin.

From a foundational standpoint, this layer builds a chain of consensus blocks, a problem that has received tremendous attention in the distributed systems arena. Yet the Blockchain consensus engine, which achieves agreement among distrusting parties in a scalable settings with unknown participants, seems very different from the classical methods for Byzantine fault tolerance (BFT).

In a recent [tutorial](https://dahliamalkhi.files.wordpress.com/2016/08/blockchainbft-beatcs2017.pdf "BlockchainBFT-BEATCS2017")  invited by the bulletin of the EATCS ([BEATCS link](http://bulletin.eatcs.org/index.php/beatcs/article/view/506)), we analyze Blockchain through the lens of the theory of distributed computing.

The tutorial covers the following three topics. First, it studies the algorithmic foundation of Nakamoto Consensus (NC), explaining how it solves (with high probability) the state-machine replication (SMR) problem. Second, it relates NC to the classical literature on Byzantine fault tolerant SMR (BFT). Finally, it overviews several approaches for bringing the two paradigms together.
