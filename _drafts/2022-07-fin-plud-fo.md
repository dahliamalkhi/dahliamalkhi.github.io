In a [previous post](..), we explained the use of a DAG, which provides a reliable, causally-ordered broadcast transport, 
in constructing message-free BFT consensus.

We can build fair ordering into DAG-based protocols in order to prevent blockchain extractable value (BEV) exploits.
Daian et al. define BEV in
[Flash Boys 2.0](https://ieeexplore.ieee.org/document/9152675)
as a measure of the profit that can be made through including, excluding, or re-ordering transactions within blocks. 
Heimbach and Wattenhoffer define 
a transaction order as fair in 
[SoK on prevention transaction reordering](https://arxiv.org/pdf/2203.11520.pdf)
``when it is not possible
for any party to include or exclude transactions after seeing their
contents. Further, it should not be possible for any party to insert
their own transaction before any transaction whose contents it
already been observed.''

Section 5.5 in
[SoK on prevention transaction reordering](https://arxiv.org/pdf/2203.11520.pdf) mentions 
other forms of algorithmic committee orderings, which do not mitigate BEV, e.g., 
[Fairledger](),
[Tusk](),
[Bullshark](). 
These works address a different notion of fairness, namely, ``chain quality'', which (informally) guarantees equal participation. 
Chain quality is not a goal we address here.

To protect against BEV, transaction information may be kept hidden until after a commit is delivered to a "blind" ordering. 
This prevents any party from observing the contents of transactions until the ordering has been committed.

One way to implement blind ordering commit/reveal is by encrypting transactions with a secret key which is shared among parties.
In a secret-sharing scheme, users send to parties a transaction digest with individual shares
Reconstructing the transaction requires a threshold greater than F of the parties to participate, 
which parties do only after observing in the DAG a commit to an ordering that includes the transaction.

The two forms differ in the manner in which the integrity of shares collected from parties can be verified.
In the threshold-crypto case, parties can attach a cryptographic proof to decryption shares during the transaction reconstruction stage. 
A threshold of correct shares guarantees correct decryption. 

In a secret-sharing scheme, users send to parties a transaction digest with individual shares
can attach proofs to shares they send to participants. 
In order to deliver a 
reliable broad

Parties deliver a re

include proofs of their shares in the DAG, not the shares themselves. 
The commit of a leader proposal orders transactions 

A 

leader proposal

