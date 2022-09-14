---
title: 'Instant Finality in Byzantine Atomic Broadcast under Unknown/Dynamic Participation'
date: 2022-08-28 00:00:00 -07:00
permalink: "/posts/2022/09/inst-finality/"
tags:
- Consensus
excerpt: A full solution for Byzantine Atomic Broadcast with instant finality when there is an unknown and dynamic set of active nodes.
category:
- new research
---

authors: Dahlia Malkhi, Atsuki Momose, Ling Ren

In this [post on blog.chain.link](https://blog.chain.link/instant-finality-in-byzantine-atomic-broadcast-under-unknown-dynamic-participation/),
we expand our previous work in the Unknown/Dynamic participation model 
from 
[**one-shot, binary** Byzantine agreement](https://blog.chain.link/instant-finality-in-byzantine-generals-with-unknown-and-dynamic-participation/). 
to multi-valued consensus on a sequence of values, i.e., solve the Byzantine atomic broadcast (BAB) problem. 
Key properties of the solutions remain, including small constant (3-round) expected latency to finality and allowing an adversary to fluctuate Byzantine parties from round to round provided that two-thirds of the active participants are honest.
