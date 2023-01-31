---
title: "STARK: A walk-through with Fibonacci"
date: 2023-02-01
layout: post
---

## Introduction

This is my second post regarding [STARK](https://eprint.iacr.org/2018/046.pdf) (or zkSTARK). [The first one](https://jinb-park.github.io/2022/12/14/stark-fri-with-concrete-numbers-for-software-engineers.html) was about the FRI protocol which is central to the fast verification of STARK. With it, I tried to explain how FRI works through a concrete set of numbers but not how the whole STARK works. Here, I'm going to walk you through the intuitions behind STARK with the Fibonacci sequence example. By the time you finish reading this, hopefully, you might be able to chain them together (STARK and FRI) in your head. Of course, there have already been two great explanatory readings ([Vitalik's](https://vitalik.ca/general/2017/11/09/starks_part_1.html) and StarkWare's) that take Fibonacci as a working example. But, in my view, they are still somewhat superficial and lack of explanation for why it is designed that way. I lost my way several times when trying to grasp them and some questions were hanging over my head and never became clear. In this article, the explanation strategy I'm gonna take throughout this article is as follows: **(1)** introduce a problem that STARK wants to efficiently solve, **(2)** show a naive method to solve, **(3)** show what STARK does to get the method better in terms of either efficiency or security, **(4)** repeat until the method becomes identical to the actual STARK. Note that I will not show you the STARK protocol in entirety instead I'll focus on the intuitions to make it more efficient or secure. Plus, mostly my explanation consists of pseudo code or just texts instead of match equations.

## A problem to solve

We assume an interactive proof scenario (or non-interactive) that the prover has a sequence of numbers and tries to convince the verifier that those numbers follow the Fibonacci sequence. The sequence of numbers called *Trace* and *Constraint* that expresses the Fibonacci look like this:

* *Trace* = { 1, 2, 3, 5, 8, 13, 21, 34 } (its length is 8)
* *Constraint*
    * *Input Boundary Constraint*: Trace\[0\] - 1 = 0    
    * *Output Boundary Constraint*: Trace\[7\] - 34 = 0  
    * *Transition Constraint*: Trace\[i\] + Trace\[i+1\] - Trace\[i+2\] = 0 (0&lt;=i&lt;=5)
        

*Trace* contains 8 numbers that conform to the Fibonacci sequence, and *Constraint* breaks down into three different parts: Input boundary (the first value must be 1), Output boundary (the last value must be 34), Transition (the Fibonacci sequence). What we have to do here is generate evaluations (points), which are compatible with the FRI verification scheme, from the given *Trace* and *Constraint*.

## 1st solution: check constraints by hand

The most straightforward way to solve this problem is to check if all constraints are satisfied upon the given trace.

1. **[prover]** send Trace and constraint expressions to the verifier. (constraint expressions are (1) Trace[0]-1=0, (2) Trace[7]-34=0, (3) Trace[i]+Trace[i+1]-Trace[i-2]=0) The prover wants to claim that "Trace" follows these expressions.

2. **[verifier]** check constraints by hand. It will look like the following code.

```python
# What the verifier needs to do
if Trace[0]-1 != 0: error
if Trace[7]-34 != 0: error

# why "len(Trace)-2"?
# Trace[6] and Trace[7] would cause out-of-index as demand Trace[8] and Trace[9] that are not in existence.
for i in range(len(Trace)-2): 
  # do constraint evaluations
  if Trace[i]+Trace[i+1]-Trace[i-2] != 0: error
```

The problem is, in this way, it gets slower as the length of Trace rises. In other words, the verification would take a linearly increasing time according to the length of Trace. What we want to do here is **make the verification process as fast as possible**, by doing a probabilistic check. That means we can inspect only one point regardless of how large Trace is, which is a good thing in efficiency but not in security.
Because, when the prover corrupts only one point and the verifier checks one random point, the attack gets caught with a very low probability, 1/8 to be exact (Trace contains 8 elements).
Well, **how can we detect this attack with a high enough probability** in practice via a single check (or a small number of check)? This is what we'll get into in the following section.

## 2nd solution: probabilistic check in a larger domain

The key idea to do it is to extend the domain and do a verification check on that extended domain. I'll explain later how it promises a high attack detection probability. First off, let's just what domains look like. We define two domains here, trace domain (d_trace) and low-degree extension domain (d_lde) which is the extended domain by blowup factor.

```python
# obtain two domains (we're working on a finite field)
p = 257   # a prime number. it's just for example.
g = 3     # generator for p
blowup = 16  # a domain will get extended by this factor.
trace = {1, 2, 3, 5, 8, 13, 21, 34} # len=8
w_trace = get_root_of_unity(p, g, len(trace))
d_trace = get_domains(p, w_trace, len(trace))  # get domain for trace
w_lde = get_root_of_unity(p, g, len(trace)*blowup) # we want a larger domain
d_lde = get_domains(p, w_lde, len(trace)*blowup) # 8*16 = 128 elements
```

The code above shows how to obtain two domains (d_trace and d_lde) considering a prime finite field (took 257 just for example. see [this post](https://jinb-park.github.io/2022/11/21/exploring-a-n-th-primitive-root-of-unity-over-finite-field-for-software-engineers.html) to find out more about n-th root of unity). As STARK requires to use finite field, we have to go this way to obtain domains.

Then, we interpolate "trace" into a polynomial and evaluate it over d_lde. It's also needed to evaluate constraints over d_lde. For the sake of simplicity, I'll take into account "transition constraint" only here.

```python
trace_poly = interpolate(d_trace, trace) # of degree 7 or less
trace_lde = [evaluation_poly_at(trace_poly, x) for x in d_lde]
# constraint evaluation over d_lde
constraint_lde = []
for i in range(len(d_lde) - 2):
  constraint_lde.append(trace_lde[d_lde[i]] + trace_lde[d_lde[i+1]] - trace_lde[d_lde[i+2]])
constraint_poly = interpolate(d_lde[:len(d_lde)-2], constraint_lde)
```

**Security enhancement.** It's time to bring up the main idea of how to check correctness with a high probability. It can be called "bounded degree testing" or "low-degree testing". Here's how it goes:

1. Denote trace_poly and constraint_poly as T(x) and C(x) respectively.
2. `C(x) = T(x) + T(x*w_trace) - T(x*w_trace^2)`, which represents transition constraint.
3. `C(x)` is a linear combination of `T(x)` which is of degree 7 or less. It says that `C(x)` also must be of a degree equal to or less than 7.

You may wonder what this degree rule has to do with a robust probabilistic check. Yes, it's still a few steps away from our actual goal so step it up one by one. First, imagine the same attack and verification method as before like this:

1. **[malicious prover]** evaluating constraints (C(x)) over d_lde (128 elements) and corrupt just one point and send those evaluations to the verifier.
2. **[verifier]** randomly pick out one point to check. The corruption would get caught with a 1/128 probability. It got even worse with a drop in detection rate from 1/8 to 1/128.

1. **[malicious prover]** evaluating constraints (C(x)) over d_lde (128 elements) and corrupt just one point and send those evaluations to the verifier.
2. **[verifier]** "C(x) must be of degree 7 or less" -> take advantage of this rule. (7 is from `degree(T(x))`)
   1. interpolate constraints into a polynomial, denoted as C'(x).
   2. C'(x) will be of degree 7 or less if there was no corruption. **If with any corruption, it'll become a poly of a larger degree than 7 with a very high probability. -> This is a key intuition here.**
3. **[verifier]** check if `degree(C'(x)) <= degree(T(x))`. A violation of this check will be treated as a verification failure.

Thus far, we've made a pretty good probabilistic check scheme. However, we're not done yet. The process above has a significant security problem. That is there is no check whether T(x) and C(x) are correctly related. Imagine this attack-- (1) a malicious prover generates an arbitrary C(x) which has nothing to with T(x) but is of degree 6 in order to avoid detection of degree check, (2) evaluating C(x) over d_lde, (3) send these constraints to the verifier, (4) the verifier cannot detect it.

To prevent this attack from happening, what we'll do is involve transition constraints in the degree testing. This is how it works:

1. **[prover]** evaluating constraints (C'(x)) in a slightly different way and sending them to the verifier.
   1. Remind the transition constraint is `C(x) = T(x) + T(x*w_trace) - T(x*w_trace^2)`.
   2. `C(x)` has to be 0 at the first five elements, i.e., at `x = {1, w_trace, w_trace^2, w_trace^3, w_trace^4}`.
   3. Then, we can rephrase `C(x)` as `C(x) = C'(x) * (x-1)(x-w_trace)(x-w_trace^2)(x-w_trace^3)(x-w_trace^4)`. The two equations get identical only if transition constraints are satisfied.
   4. Denote `(x-1)(x-w_trace)(x-w_trace^2)(x-w_trace^3)(x-w_trace^4)` as `Z(x)` (zerofier). Then, `C'(x) = C(x) / Z(x)`.
   5. Finally, we can assert that `degree(C'(x)) <= degree(T(x)) - degree(Z(x))` (`degree(C'(x)) <= 2`) if no corruption.
   6. Evaluate `C'(x) = C(x) / Z(x)`.
2. **[verifier]** interpolate constraints into a polynomial, denoted as C'(x).
3. **[verifier]** check if `degree(C'(x)) <= degree(T(x)) - degree(Z(x))` (i.e., `degree(C'(x)) <= 1`)

This way, the prover is required to do more work (division by Z(x)) while the amount of work dedicated to the verifier is not changed. Despite this change, an attack with an arbitrarily generated C'(x) still could work out, because the prover can circumvent it by generating a poly of degree 1 and evaluating it and sending it to the verifier. That implies we still lack a way to check the T(x)-C'(x) relationship. *Consistency check* at an out-of-domain point comes to the rescue:

1. **[prover]** evaluating constraints (C'(x)) considering the respective zerofiier. (Z(x))
2. **[verifier]** interpolate constraints into a polynomial, denoted as C'(x).
3. **[verifier]** do a consistency check first.
   1. randomly choose an out-of-domain point. As we're working on a prime finite field of 257, I'll take 254 for that point. (this point has to belong to a finite field)
   2. do a consistency check at 254, which means checking if `C'(254) = ((T(254)+T(254*w_trace)-T(254*w_trace^2)) / Z(254)`. Not matched, this verification process will terminate.
4. **[verifier]** do a bounded degree check: check if `degree(C'(x)) <= 2`.

Under the reinforced protocol shown above, a randomly generated C(x) by a malicious prover will get caught in a consistency check. Summing it up, the verification breaks into two phases: (1) do a *consistency check* if T(x) and C'(x) are correctly related, (2) do a *degree check* if all constraints are held.
Well, are we done finally? Not yet. let's turn our focus to a matter of efficiency we've put aside so far.

## 3rd solution: + faster low-degree testing

There is some intentionally omitted efficiency matter in the last secure protocol I showed you. That is the verifier has to interpolate evaluation constraints into a polynomial to put the bounded degree check in practice. This brings on a linearly increasing time complexity upon the length of the trace, which is what we're trying to eliminate for efficiency. So, we need to figure out a way to make this low-degree testing faster, up to as fast as constant-level complexity. This is where [FRI](https://jinb-park.github.io/2022/12/14/stark-fri-with-concrete-numbers-for-software-engineers.html) comes into play. I'll not detail how FRI works here instead say what FRI brings to the table. Roughly speaking, FRI can speed up the last bound degree check:

1. **[prover]** evaluating constraints (C'(x)) and sending only *N evaluations* (*N* has nothing to do with the length of the trace) to the verifier.
2. **[verifier]** do a consistency check at an out-of-domain point.
3. **[verifier]** invoke FRI with *N evaluations* as input. FRI can determine if `degree(C(x)) <= degree(T(x))` even with partial evaluations (N).

Here, the point is *N evaluations*. FRI is what can not only make low-degree testing faster but also make it happen only with partial evaluations. The verifier doesn't have to interpolate all constraints. Instead, it only demands N (constant and configurable) evaluations, which in turn leads to constant-time complexity.

One more thing worth noting is positions to verify (i.e., pick out N evaluations) have to be randomly chosen by the verifier for security reasons.

We're getting close to the end of this journey but not yet. I've mentioned so far only transition constraints for the sake of simplicity. But, recall that what we have to verify is not only transition but also input and output boundary constraints. Having three different transitions to verify says that we have to run the above protocol, including FRI, three times respectively. (it may need more upon a requirement) The next thing we do is to eliminate this inefficiency.

## 4th solution: + random linear combination of polynomials

This time, we aim to make three different polynomials into a single constraint polynomial so that doing the verification only once would be enough. Denote transition constraint polynomial and input boundary constraint polynomial and output boundary constraint polynomial as CT(x) and CI(x) and CO(x), respectively.
What we'll ultimately do is do a random linear combination of polynomials, which looks like `C(x) = a*CT(x) + b*CI(x) + c*CO(x)` where a and b and c are a random constant value. (see [this post](https://jinb-park.github.io/2023/01/17/a-secure-random-linear-combination-of-polynomials.html) to get why random constants are necessary here) Like the degree constraint of CT(x), CI(x) and CO(x) have to be of less than a certain degree. Here are three different degree constraints:

```
1: CT(x) = (T(x)+T(x*w_trace)-T(x*w_trace^2)) / (x-1)(x-w_trace)(x-w_trace^2)(x-w_trace^3)(x-w_trace^4)
    => degree(CT(x) <= degree(T(x)) - 5
    => degree(CT(x) <= 2
2: CI(x) = (T(x)-1) / (x-1)
    => degree(CI(x)) <= 6
3: CO(x) = (T(x)-34) / (x-w_trace^7)
    => degree(CO(x)) <= 6
```

As you can see, different kinds of polynomials can have different degrees. So, we have to lift them to the same degree by using *adjustment degree*. For example, `CT(x)*x^4` yields `degree(CT(x)) <= 6` which is equivalent to the other two. You may wonder why this adjustment is needed because it seems that adding the three polynomials without adjustment leads to `degree(C(x)) <= 6` anyhow. This has to do with a security issue that can arise in no use of adjustment.

Imagine a transition constraint gets violated, and then `degree(CT(x))` can become larger than 2 (assume it becomes 3). If no adjustment, a linear combination of these three polynomials becomes a poly of less than 6 and it will pass the verification check because the constraint violation won't get it to exceed degree 6.
With adjustment degree, `degree(CT(x))` would go beyond degree 6, as a result, it can get caught.

Putting it all together, here's how it works (applying adjustment degree is omitted):

1. **[prover]** evaluate all kinds of constraints, CT(x) and CI(x) and CO(x).
2. **[prover]** do a random linear combination to make them into a single polynomial: `C(x) = a*CT(x) + b*(CI(x) + c*CO(x))`, and evaluate the combined polynomial C(x) and send N evaluations to the verifier.
3. **[verifier]** do a consistency check at an out-of-domain point.
4. **[verifier]** invoke FRI. FRI can determine if `degree(C(x)) <= degree(T(x))`. (Note that more precisely this check statement is subject to change according to adjustment degree)

Finally, we're done-! But, I should reiterate the fact that this article focuses on exploring the main intuitions used in STARK through a concrete example, instead of giving a ton of math equations that explains STARK as a whole. So, I have to admit that lots of details are not covered, that is to say if you're interested in building STARK from scratch or going over some existing STARK implementation, you would have to dig deeper into STARK. Here's a short (yet incomplete) list of what I omitted:

- how to build a single composition polynomial that associates between trace and constraint polynomial, which can render a separate consistency check unnecessary.
- the medium of sending N evaluations to the verifier. -> Merkle tree is heavily used throughout STARK for this purpose.
- how a proof object comprises. --> What I mean by a proof object is all data needed to be passed on from the prover to the verifier. It requires a wide range of data but what I mentioned was a simplified one.
- how to turn it into a non-interactive proof.
- how to add zero-knowledge property, which means how to keep some of the traces secret. (see [this blog post](https://aszepieniec.github.io/stark-anatomy/stark#fn:1)'s "Adding Zero-Knowledge" part for it)
- perhaps more...

## Note: zkVM

There is another interesting way of solving the same problem of our interest. We mathematically modeled the Fibonacci sequence through this equation: `T(x) + T(x*w_trace) + T(x*w_trace^2) = 0`. But we can express the same one as a programmable function that computers can execute, as follows.

```C
int fibonacci(int n) {
  int array[256] = {0,};
  array[0] = 1;
  array[1] = 2;
  for (i=2; i<=n; i++) {
    array[i] = array[i-1] + array[i-2];
  }
  return array[n];
}
```

This program (written in C) can be compiled into a specific target binary (e.g., x86_64 or ARM) or directly run on an interpreter. Either way, some machine will run this program. A way to make sure this Fibonacci behaves correctly at all points is to treat each instruction of the machine executing it as one that alters machine states between two consecutive cycles and to associate such instructions with STARK constraints.

Imagine there is a simple machine that has only two registers (R0, R1) and add operation. Each register can be regarded in STARK as one trace column.
Take these instructions `0. R0 = 1, R1 = 2; 1. R0 = R0 + R1; 2. R1 = R0 + R1` for example. In STARK, they can be expressed as follows:

- `Trace_R0 = {1, 3, 3}` -> Trace_R0[i] represents the value of the R0 register at i-th instruction.
- `Trace_R1 = {2, 2, 5}` -> Trace_R1[i] represents the value of the R1 register at i-th instruction.
- Input boundary constraint
  - Trace_R0[0] - 1 = 0
  - Trace_R1[0] - 2 = 0
- Output boundary constraint
  - Trace_R0[2] - 3 = 0
  - Trace_R1[2] - 5 = 0
- Transition constraint
  - We have to express add instruction in a transition constraint. 
  - `Rn_i = Rn_i-1 + Rk_i-1` (i means i-th instruction) yields two constraints: (1) `Rn_i = Rn_i + Rk_i`, (2) `Rk_i = Rk_i-1`. In other words, whenever we encounter an add instruction, we need to change it into these two constraints and involve them in STARK verification.

This is a simplified explanation of how to apply STARK to a simple virtual machine to verify the correct execution of a program.
If we target a more general-purpose virtual machine like RISC-V or EVM, we can build and run any programs on top of the zero-knowledge nature.
There are already some great projects in existence for this purpose. (e.g., [RiscZero](https://www.risczero.com/), [Polygon Miden VM](https://github.com/0xPolygonMiden/miden-vm))