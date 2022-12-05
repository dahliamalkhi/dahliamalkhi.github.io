---
title: 'The Latest View on View Synchronization'
date: 2022-12-05 00:00:00 -07:00
permalink: "/posts/2022/11/pacemakers/"
tags:
- Consensus
header:
  teaser: "/images/pacemaker.png"
  overlay_image: "/images/pacemaker.png"
  overlay_filter: rgba(0, 100, 100, 0.8)
excerpt: An evolution of “Pacemaker” solutions to the Byzantine View Synchronization problem finally led to optimal communication-complexity solutions. 
category:
- tutorial
---

authors: Dahlia Malkhi, [Oded Naor](https://www.odednaor.work/)

Steady progress in the practicality of leader-based Byzantine consensus protocols, including the introduction of HotStuff—whose leader protocol incurs only a linear communication cost—shifts the challenge to the “Pacemaker” part, which is responsible for View Synchronization.

More specifically, before HotStuff, BFT solutions for the partial synchrony settings required quadratic communication complexity per view (with a new leader), hence no one cared if coordinating entering/leaving a view also incurs quadratic communication. HotStuff demonstrated a protocol whose per-view complexity is (always) linear and also defined the Pacemaker as a separate component of BFT consensus. 
Thus, the challenge has shifted to developing a Pacemaker with low communication efficiency.

our post [The Latest View on View Synchronization](https://blog.chain.link/view-synchronization/)
provides a foundational perspective on the evolution of Pacemaker solutions to the Byzantine View Synchronization problem.
Spoiler alert: The theoretical worst-case communication lower bound for reaching a single consensus decision is quadratic, but only this year has this complexity (finally) been achieved; these quadratic Pacemakers are described in the post.

