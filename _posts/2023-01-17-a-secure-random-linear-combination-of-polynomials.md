---
title: "A secure random linear combination of polynomials"
date: 2023-01-17
layout: post
---

## Introduction

In this article, I will discuss how a linear combination of polynomials is used in a very specific circumstance. A linear combination of polynomials is used to combine multiple polynomials into a single polynomial. For example, there are two polynomials, *P(x)* and *Q(x)*, and these two can be merged as a single polynomial, `L(x) = a*P(x) + b*Q(x)` where a and b are constant. We can call *L(x)* a linear combination of *P(x)* and *Q(x)*. Simple as that. This is a very generic concept but what I'll focus on is how to get this combination way better in a specific interactive proof scenario. This article will proceed as follows: **(1)** share an example protocol in which the prover wants to prove something to the verifier. **(2)** show you a strawman solution to this protocol, which has no optimization. **(3)** explain how to optimize the solution using a linear combination but in an insecure fashion. **(4)** make it secure so that building a secure yet fast protocol.

## A problem to solve

As mentioned earlier, I'll give you a problem of interactive proof that the prover and the verifier are involved in. The environment they are in is as follows:

* There are two polynomials of degree 2, `P(x)=2x^2+x` and `Q(x)=3x^2+1`.
    
* There are evaluations of P(x) and Q(x) at `x=1~5`, `P_ev={3,10,21,36,55}`, `Q_ev={4,13,28,49,76}`.
    
* `P_ev` and `Q_ev` are assets that belong to the prover. And, the prover wants to convince the verifier that P(x) and Q(x) are of degree 2.
    

You can see this example as a similar kind of low-degree testing used in [STARK FRI](https://jinb-park.github.io/2022/12/14/stark-fri-with-concrete-numbers-for-software-engineers.html) as P\_ev and Q\_ev contains more points than needed to build a polynomial of degree 2. Actually, the solutions we're going to explore in the following are similar in concept to the ones used in [STARK](https://eprint.iacr.org/2018/046.pdf).

## A strawman solution

Let's start with a strawman solution (protocol) to solve the problem. No doubt that the most straightforward way is just sending P\_ev and Q\_ev to the verifier and checking if they both are of degree 2.

1. **&lt;prover&gt;** send P\_ev and Q\_ev to the verifier.
    
2. **&lt;verifier&gt;** check if P\_ev is of degree 2; more technically interpolate a polynomial of degree 2 by picking any three points in P\_ev, and check if the other two points are on the polynomial.
    
3. **&lt;verifier&gt;** do the same check for Q\_ev.
    

However, this solution would get slower at a linear pace when there come more polynomials to check than 2 (i.e., P\_ev and Q\_ev). How can we eliminate this linear time complexity, thereby building a faster solution? The optimization to this problem could come from a linear combination, that is to say, the prover combines P(x) and Q(x) into a single polynomial (named L(x)) and evaluates L(x) on the same domain and sends L\_ev (evaluations on L(x)) to the verifier. In this way, checking only once is enough to verify the correctness of the prover. This argument is based on the fact that the degree of a linear combination(`L(x) = a*P(x) + b*Q(x)`) must be 2 if the degree of P(x) and Q(x) is 2.

## An optimization using a linear combination

See how a linear combination based optimization works and how it gets insecure without special care. Let's say that `L(x) = P(x) + Q(x)` (i.e., a=1 and b=1). An optimized version of this protocol works as follows, along with a genuine prover.

1. **&lt;prover&gt;** send `P_ev={3,10,21,36,55}` and `Q_ev={4,13,28,49,76}` to the verifier.
    
2. **&lt;prover&gt;** compute L\_ev using `L(x) = P(x) + Q(x)`, then `L_ev={7,23,49,85,131}`.
    
3. **&lt;verifier&gt;** check if L\_ev is on a polynomial of degree 2.
    

Everything works well when the prover is authentic. But, what if a possibly malicious prover comes in? Can this protocol prevent the malicious prover from cheating the verifier?

1. **&lt;prover&gt;** send `P_ev={3,10,*20*,36,55}` and `Q_ev={4,13,*29*,49,76}` to the verifier. The malicious prover changes P\_ev\[2\] from 21 to 20 and Q\_ev\[2\] from 28 to 29 so that P(x) and Q(x) are no longer of degree 2. In this case, is it possible for the prover to cheat the verifier that P(x) and Q(x) are still of degree 2?
    
2. **&lt;prover&gt;** compute L\_ev using `L(x)=P(x)+Q(x)`, then `L_ev={7,23,49,85,131}`. Even though P(x) and Q(x) are not of degree 2, you can see that L(x) is still of degree 2.
    
3. **&lt;verifier&gt;** check if L\_ev is on a polynomial of degree 2. This verification check will pass, in other words, the malicious prover ends up undetected.
    

Why does this cheating get viable? That's because we use the fixed constant (1) for a and b in building a linear combination. In the first step above, a malicious prover can corrupt P\_ev and Q\_ev which lead to L\_ev of degree 2, as he at this moment already knows what L(x) is. To defeat this attack, we need to add interactiveness and randomness to this protocol.

## Optizimation + Security

Let's go straight into how a more secure version can stop the aforementioned attack.

1. **&lt;prover&gt;** send `P_ev={3,10,*20*,36,55}` and `Q_ev={4,13,*29*,49,76}` to the verifier. This is based on a guess that a=1 and b=1, and `L(x)=P(x)+Q(x)`.
    
2. **&lt;verifier&gt;** generates random a and b which would become coefficients of L(x), and send them to the prover. Assume that a=3 and b=2.
    
3. **&lt;prover&gt;** compute L\_ev using `L(x)=3*P(x)+2*Q(x)`, then `L_ev={17,56,118,206,317}`.
    
4. **&lt;verifier&gt;** check if L\_ev is on a polynomial of degree 2. This verification check will not pass. (NOTE: the verifier has to recompute L\_ev using P\_ev and Q\_ev sent in the first step)
    

In the updated protocol above, the malicious prover at Step 1 is required to send P\_ev and Q\_ev prior to L(x) being determined because the verifier interposes between Step 1 and Step 3 and generates random a and b. So, the only thing the prover could do is make a rough guess on a and b, and compute P\_ev and Q\_ev on top of it. As any of the two (a or b) doesn't match with a high probability, the verifier can readily detect this attack.

Thus far, we've built a fast yet secure interactive proof system to prove multiple polynomials are of a certain degree. Lastly, I'll show you how to turn it into a non-interactive one using [the Fiat-Shamir heuristic](https://jinb-park.github.io/2022/12/08/fiat-shamir-heuristic-in-the-eyes-of-attackers.html).

## Turning to a non-interactive one

With the Fiat-Shamir heuristic (i.e., the use of a cryptographic hash function), we can eliminate unnecessary communications between the prover and the verifier.

1. **&lt;prover&gt;** send `P_ev={3,10,21,36,55}` and `Q_ev={4,13,28,49,76}` to the verifier.
    
2. **&lt;prover&gt;** compute `a = Hash(P_ev)` and `b = Hash(Q_ev)`, then `L(x) = a*P(x) + b*Q(x)`, and compute L\_ev using the L(x) and send L\_ev to the verifier.
    
3. **&lt;verifier&gt;** compute a and b using P\_ev and Q\_ev sent in the first step, and rebuild L\_ev on top of it, and check if L\_ev is on a polynomial of degree 2.
    

To get why it is as secure as the interactive one, try corrupting any of P\_ev and see what happens next. If the prover speculates a=1 and changes P\_ev\[2\] from 21 to 20, "a" will differ from "1" with a high probability, which leads to a verification failure in the last step.