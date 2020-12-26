---
title: 'The Greek Tragedy of Industrial Computing Research Labs'
date: 2017-10-29
permalink: /posts/2017/10/industrial-research-labs
tags:
  - BFT
  - consensus
---

Authors: Guy Singer and Dahlia Malkhi

The recent passing of  [Bob Taylor](https://www.nytimes.com/2017/04/14/technology/robert-taylor-innovator-who-shaped-modern-computing-dies-at-85.html?_r=0)  resurfaced the fascinating love-hate relationship of industrial research labs across generations.

In 1970, to prepare itself for a future of digital documents, Xerox founded the Palo Alto Research Lab (PARC) and brought George Pake to manage it. Pake set up several labs within PARC, among them the Computer Science Lab (CSL), which Bob Taylor was brought to run. The story of PARC is a remarkable tale of vision, brilliance and extraordinary technical and technological accomplishments. PARC invented the first personal computer, the Ethernet, the first mouse, the laser printer, object-oriented programming, graphic displays, and a dozen other “firsts.”

At the same time, PARC is a story of missed opportunities, and of miscommunication between a research arm and the parent company. One view, covered in the PARC Chronicles (see “[Fumbling the Future](https://www.amazon.com/Fumbling-Future-Invented-Personal-Computer/dp/1583482660),” Douglas Smith and Robert Alexander), speaks of misalignment between researchers who failed to make necessary pragmatic accommodations, and company management who failed to bridge the gap. Most of all, it is a story of how people failed, not their technical innovation. In the end, Xerox leveraged only a fraction of the PARC inventions and missed dominating the desktop/PC market. The conceptual innovations that emanated from PARC survived nevertheless and still illuminate scientists to this day.

I personally feel very fortunate to still be working in an industrial research lab,  [VMware Research](https://research.vmware.com/). There is a chain of research labs starting with PARC, where VMware Research is in some sense the “fourth incarnation”:

In 1984, Bob Taylor left PARC and founded DEC SRC. A dozen PARC CSL researchers left in solidarity and joined him at SRC, a lab that contributed to many important innovative technologies such as  [Petal](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.44.1058&rep=rep1&type=pdf), the first virtualized scale-out storage and  [Alta Vista](https://en.wikipedia.org/wiki/AltaVista), the first web search engine with fully automated indexing. Bob retired in 1996 and handed the reins over to Roy Levin who eventually ended up co-founding and leading  [MSR SVC](http://msrsvc.org/).

MRC SVC gave the computing world two Turning Award laureates,  [Charles P. Thacker](http://amturing.acm.org/award_winners/thacker_1336106.cfm)  and  [Leslie Lamport](http://amturing.acm.org/award_winners/lamport_1205376.cfm). Cynthia Dwork and her team, while working at MRC SVC, established the field of differential privacy in 2006 which won the  [2017 Gödel prize](https://www.eatcs.org/index.php/component/content/article/1-news/2450-2017-godel-prize). Microsoft did not leverage this technology; however, a decade later, Apple and Google are now embracing DP in their products. SVC also pioneered  [Local Reconstruction Codes](https://www.microsoft.com/en-us/research/blog/the-code-that-no-one-in-the-cloud-can-live-without/)  (LRC) in cloud storage clusters, which is used, by Microsoft and others today.

After 13 years of prospering and thriving, on September 18th, 2014, the researchers of Microsoft Research Silicon Valley,  [MSR SVC](http://msrsvc.org/), woke to an e-mail sent at 7 am inviting them to a special meeting with the VP of research. At 10 am, the majority of the stunned researchers were handed their notice.

On the last day at SVC, the researchers met for a farewell toast. Although almost three years have passed, my memory of that somber day is quite vivid. My recollection of Roy Levin’s departing words:

_Thank you for all the great work you put in over the years, it was highly appreciated and impactful. Companies are just institutions made from people; they come and go. But look to your left and to your right, the human connections you create throughout your career remains._

# Aftermath

By early 2015, the team from SVC has scattered and the joint, critical mass they formed at Microsoft was lost forever. However, the knowledge left with them, their connections went wherever they did, and in fact, the people popped in leading, distinguished technical positions at the top Silicon Valley companies and in academia, including, but not limited to, VMware Research. They continue to fertilize and drive innovation wherever they are.

The demise of SVC was not taken lightly (see, e.g.,  [SIGACT letter](https://thmatters.wordpress.com/2014/10/14/letter-re-closing-of-microsoft-research-silicon-valley/)) and brings up the dilemma and the perpetual concern: Everyone wants industrial research labs, but will there always be someone to support it? What will it take for a research lab to survive?

Industrial research labs have been around in the United States long before the age of computing. General Electric first opened its laboratory doors in 1900, AT&T in 1911, and as early as 1920 nearly 300 major U.S. companies actively funded pure research laboratories (Bulletin of the National Research Council, 1920). By 1930 the number of companies increased to 1,600, and by the 1940s it was closer to 3,000 (Reich, 1985). Unsurprisingly, in these earlier days of industrial research, chemists and engineers dominated the field. However, the Greek tragedy of industrial computing research, which would only come decades later, is especially poignant in illustrating the shift in industry leaders’ approach to pure research.

Companies form research labs to bring excellence to the organization and guarantee their R&D is in touch with leading edge disruptions. As long as this remains the expectation, things work fine. Over the long haul, they bring remarkable disruption to the computer science field, and the company has “first hand” access to the expertise around these disruptions.

However, frequently, the company cannot instantly monetize these disruptions, and discontinues the work; shifts focus; reorganizes; or closes down. When a company stops investing in unfettered research, they lose their most valuable asset, top talent that holds deep domain expertise. They also lose ideas and technologies, which by many historical precedents, are eventually bound to drive impact throughout the market. Some may take a decade to be recognized, but the stellar impact on the area of computing is born out of labs. In many cases, the technology impact outlives the lab itself!

If you ask leading technologists in large companies their opinion on how to leverage research in an industrial setting, you will likely hear very passionate and diverse answers. A somewhat pessimistic view is “[The Decline of Unfettered Research](http://www.pantaneto.co.uk/issue56/odlyzko.htm),” where Andrew Odlyzko argues that directed short-term research is the best approach to lead to incremental improvements. “Incremental improvements have been much more important than striking new inventions.”

In addition to VMware, other recently established research groups are abundant in the Silicon Valley, including,  [Baidu](http://research.baidu.com/),  [Alibaba](http://www.missqt.com/alibaba-cloud-appoints-dr-zhou-jingren-as-chief-scientist-leading-leading-big-data-and-artificial-intelligence-research-at-alibaba-idst/),  [Visa](http://research.visa.com/), [Samsung](http://www.sra.samsung.com/), and  [Huawei](http://innovationresearch.huawei.com/IPD/hirp/portal/index.html).

What will it take for these labs to survive? What have we learned from the tragedies of the past? At the end of the day, the success of the parent company, its needs, and the value it places on technical excellence are probably the most dominant in determining the fate of a research lab.

Still, as long as it thrives, research can bring a unique value. Rather quickly after  [VMware Research](https://research.vmware.com/) has been founded, it engaged broadly and deeply in innovative work within the organization. A sampler of works appears in [SIGOPS OSR, Sep 2017 special issue on VMware Research](https://dl.acm.org/citation.cfm?id=3139645&CFID=1000742815&CFTOKEN=72988258). At VMware Research, we borrow heavily from Roy Levin’s model, described in “[A Perspective on Computing Research Management](http://msrsvc.org/roylevin/osrresearchmgmt.pdf).” Levin believes the best-proven record of accomplishment is when the corporate research labs operate “university-like.”

Adding briefly, my own guiding principles are:

-   Remain small. There is no reason why a research lab be larger than a typical CS faculty. Big projects are not the goal of a research group; they may be spun off, but not remain a part of the small group.
-   Maintain a differentiating, uncompromising quality. A good guideline is the caliber of the top CS departments in the world. Researchers should be experts in their fields, and portray unquestionable authority that R&D folks in the organization can count on.
-   Execute! Research labs have the benefit of resources and delivery power of an industrial setting. The researchers in these labs would be wise to embrace the tremendous opportunities and vehicles at their disposal for driving impact. “I like working in an industrial research lab, because of the input”, Leslie Lamport, 2013 Turning award winner, said. “If I just work by myself and come up with problems, I’d come up with some small number of things, but if I go out into the world, where people are working on real computer systems, there are a million problems out there. When I look back on most of the things I worked on—Byzantine Generals, Paxos—they came from real-world problems.”
-   Curb your expectations. Anticipating disruption on a timeline is impossible, and expecting it will only lead to disappointment and frustration. Eventually, it also leads labs to shut down.

## Acknowledgement

I am indebted for valuable input I received for this blogpost from Ellen Herrick, technical writer, Roy Levin and Udi Wieder.

# Further Reading

Douglas K. Smith (Author), Robert C. Alexander (1999).  _Fumbling the Future: How Xerox Invented, then Ignored, the First Personal Computer._  [https://www.amazon.com/Fumbling-Future-Invented-Personal-Computer/dp/1583482660](https://www.amazon.com/Fumbling-Future-Invented-Personal-Computer/dp/1583482660)  .

ACM SIGACT Committee for the Advancement of Theoretical Computer Science, jointly with individual leaders across academic departments (1994).  _Letter re closing of Microsoft Research Silicon Valley._  [https://thmatters.wordpress.com/2014/10/14/letter-re-closing-of-microsoft-research-silicon-valley/](https://thmatters.wordpress.com/2014/10/14/letter-re-closing-of-microsoft-research-silicon-valley/)

Odlyzko, A. (1994). The Decline of Unfettered Research. _The Pantaneto Forum_, (56).  [http://www.pantaneto.co.uk/issue56/odlyzko.htm](http://www.pantaneto.co.uk/issue56/odlyzko.htm)

Levin, R. (2007). A Perspective on Computing Research Management.  _ACM Operating Systems Review_,  _41_(2), pp. 3-9.  [http://msrsvc.org/roylevin/osrresearchmgmt.pdf](http://msrsvc.org/roylevin/osrresearchmgmt.pdf)

National Research Council (U.S.). Research Information Service (1921):  [Research laboratories in industrial establishments of the United States, including consulting research laboratories.](https://catalog.hathitrust.org/Record/002092114)

Reich, Leonard (1985).  _The Making of American Industrial Research_. Cambridge, United Kingdom: Cambridge University Press.

Microsoft Corporation,  _Leslie Lamport Receives Turing Award_. 18 March 2014.  [http://research.microsoft.com/en-us/news/features/lamport-031814.aspx](http://research.microsoft.com/en-us/news/features/lamport-031814.aspx)  .

Mark Silberstein and Christopher J. Rossbach (Eds.). 2017.  [Special Topics.  _SIGOPS Oper. Syst. Rev._  51, 1 (September 2017)](https://dl.acm.org/citation.cfm?id=3139645&CFID=1000742815&CFTOKEN=7298825) .
