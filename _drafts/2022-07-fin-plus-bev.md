In a [previous post](..), we explained the use of a reliable, causally-ordered broadcast DAG transport 
in constructing message-free BFT consensus.

We can build fair ordering into DAG-based BFT Consensus protocols
in order to prevent blockchain extractable value (BEV) exploits.
BEV is a measure introduced by Daian et al. in
[Flash Boys 2.0](https://ieeexplore.ieee.org/document/9152675)
of the "profit that can be made through including, excluding, or re-ordering transactions within blocks". 
It is related to and replaces a previously coined measure called maximal extractable value (MEV).
Heimbach and Wattenhoffer define 
in [SoK on preventing transaction reordering](https://arxiv.org/pdf/2203.11520.pdf)
a transaction ordering as _fair_ "when it is not possible
for any party to include or exclude transactions after seeing their
contents. Further, it should not be possible for any party to insert
their own transaction before any transaction whose contents it
already been observed." 
Section 5.5 in the SoK mentions other forms of algorithmic committee orderings, e.g., 
[Fairledger](),
[Tusk](),
[Bullshark](). 
These works address a different notion of fairness that (informally) guarantees equal participation but not BEV mitigation. 
In fact, a corrupt party may take advantage of the equal participation privilege to front-run transactions it has already observed.

To protect against BEV, transaction information may be kept hidden until after a commit is delivered on a "blind" ordering. 
This prevents any party from observing the contents of transactions until the ordering has been committed.

To order transactions blindly, 
users should broadcast encrypted transactions to the Consensus parties, 
such that decrypting a transaction requires a threshold greater than F of the parties to participate. 
Parties must contribute to decrypting a transaction only after observing the transaction committed in the DAG.

One way to implement this is using pub/private key encryption, 
such that the public key is known to users and the private key is shared (at setup time) among parties.
Another way is for users to encrypt each transaction with a symmetric key chosen for it, 
and share the key among parties using Shamir's secret sharing scheme.

The two forms differ in the manner in which the integrity of shares collected from parties can be verified.
Public key encryption schemes allow to verify that a party is contributing a correct decryption share and furthermore, 
a threshold of honest parties can always succeed in decrypting. 

In the secret-sharing scheme,
a bad user might send bogus shares to some parties.
Hence, reconstructing the key from different subsets of parties might produce different keys. 
The solution is either employing a verifiable secret-sharing scheme (VSS),
that can be implemented inside the echo broadcast protocol, e.g., 
employing a scheme by Basu et al. for efficient
[asynchronous VSS in BFT Consensus](https://dahliamalkhi.github.io/files/T3P-CCS19.pdf).

There is another alternative that foregoes VSS secret-sharing verification completely and utilizes another Consensus round instead. 
The idea is that when a DAG commit is observed, it is regarded as provisional. 
For each provisional transaction which has not committed yet,
the leader of the next view collects key shares (signed by the user) from F+1 parties
and posts them inside its proposal. 
In this way, there is agreement about how to decrypt (or about failing to decrypt) committed transactions.
