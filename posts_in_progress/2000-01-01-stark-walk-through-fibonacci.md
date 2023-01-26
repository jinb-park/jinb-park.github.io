---
title: "STARK: A walk-through with Fibonacci"
date: 2000-01-01
layout: post
---

## Introduction

This is my second post regarding [STARK](https://eprint.iacr.org/2018/046.pdf) (or zkSTARK). [The first one](https://jinb-park.github.io/2022/12/14/stark-fri-with-concrete-numbers-for-software-engineers.html) was about the FRI protocol which is central to the fast verification of STARK (I recommend reading the first post regarding FRI before getting into this article). With it, I tried to explain how FRI works through a concrete set of numbers but not how the whole STARK works. The aim of this article is to walk you through the design of STARK with the Fibonacci sequence example. By the time you finish reading this, you might be able to chain them together (STARK and FRI) in your head (I hope). Of course, there have already been two great explanatory readings ([Vitalik's](https://vitalik.ca/general/2017/11/09/starks_part_1.html) and StarkWare's) that take Fibonacci as a working example. But I think they are still somewhat superficial and lack some details from the view of engineering, which may lead to software engineers struggling. To make it clearer, the explanation strategy I'm gonna take throughout this article is as follows: **(1)** introduce a problem that STARK wants to efficiently solve, **(2)** share a concrete set of numbers as an initial setup to approach the problem, **(3)** show a naive method to solve, **(4)** show what STARK does to get the method better in terms of either efficiency or security, **(5)** repeat until the method becomes identical to the actual STARK.

## A problem to solve

We assume an interactive proof scenario (or non-interactive) that the prover has a sequence of numbers and tries to convince the verifier that those numbers follow the Fibonacci sequence. The sequence of numbers called *Trace* and *Constraint* that expresses the Fibonacci look like:

* *Trace* = { 1, 2, 3, 5, 8, 13, 21, 34 } (its length is 8)
    
* *Constraint*
    
    * *Input Boundary Constraint*: Trace\[0\] - 1 = 0
        
    * *Output Boundary Constraint*: Trace\[7\] - 34 = 0
        
    * *Transition Constraint*: Trace\[i\] + Trace\[i+1\] - Trace\[i+2\] = 0 (0&lt;=i&lt;=5)
        

*Trace* contains 8 numbers that conform to the Fibonacci sequence, and *Constraint* breaks down into three different parts: Input boundary (the first value must be 1), Output boundary (the last value must be 34), Transition (the Fibonacci sequence). What we have to do here is generate evaluations (points), which are compatible with the FRI verification scheme, from the given *Trace* and *Constraint*.

## An initial setup

The table below enumerates an initial setup to perform this proof. These terms will be used throughout this article. Worth noting that *max\_constraint\_degree* is not necessary but stands for the sake of simplicity. Specifically, it indicates how many trace values at most are allowed to get involved in a constraint. For example in Fibonacci, the transition constraints involve three traces, which are under this configuration. And, there are three different domains: *d\_trace*, *d\_lde*, and *d\_ev*. I will not explain here what low degree extension (*d\_lde*) means and why it matters. If you're not familiar with it, I recommend you read [Vitalik's](https://vitalik.ca/general/2017/11/09/starks_part_1.html) post before moving on.

| key | value | comment |
| --- | --- | --- |
| prime number (*P*) | 257 | use a small prime number for testing purposes |
| generator (*G*) | 3 | generates 256 elements |
| blowup | 16 | used to extend a trace |
| max\_constraint\_degree | 8 | used for the sake of simplicity |
| d\_trace\_len | 8 | the length of the execution Trace |
| d\_trace | ~ | trace domain with w\_trace as root of unity |
| d\_lde\_len | 128 | \= d\_trace\_len \* blowup |
| d\_lde | ~ | low degree extension domain (extended trace) with w\_lde as root of unity |
| d\_ev\_len | 64 | \= d\_trace\_len \* max\_constraint\_degree |
| d\_ev | ~ | evaluation domain with w\_eval as root of unity |

And in a nutshell, what we're going to ultimately do is compute constraint evaluations that reflect whether *Trace* follows those given constraints.

## Computing constraint evaluations

### For the input boundary constraint

A high-level strategy to check constraints is to have some expressions fall to zero only if a given constraint is satisfied. And then, only if it's the case (falling to zero) polynomial divisions would leave no remainder. (TODO) Let's see an actual example of the input boundary constraint "Trace\[0\] - 1 = 0".

1. `P(x) = T(x) - 1` : T(x) is a polynomial of interpolating Trace. P(x) represents the input boundary constraint and should get "zero" at "x = w\_trace\_0 (1)" which is the first element of the trace domain, d\_trace.
    
2. `P(x) = C(x) * D(x)` : rephrase P(x) through C(x) and D(x), where C(x) is a constraint polynomial of our interest.
    
3. `P(x) = C(x) * (x-1)` : D(x) can be replaced with (x-1), in more general term (x-w\_trace\_0). This is a way to make sure that P(x) gets "zero" at "x = w\_trace\_0". Through this equation, we can get the below condition to check later.
    
    1. `C(x) = P(x) / (x-1)` : P(x) must be divisible by (x-1), that is to say, when P(x) divides (x-1) there must be no remainder left.
        
    2. `deg(P(x)) = deg(C(x)) + 1` : deg(P) is always larger than deg(C) by 1.
        

Then, let's compute constraint evaluations for the input boundary constraint, not considering *d\_lde* and *d\_ev*. In other words, I'd like to start off with only *d\_trace* for simplicity. This code checks whether *Trace* follows the input boundary constraint and can be seen as a simplified implementation of the above explanation about how to compute constraint evaluations. If you change Trace\[0\] from 1 to something else, it couldn't pass the below remainder check.

```python
px_ev = [(x - 1) for x in Trace]  # it means evaluating 'P(x) = T(x) - 1' on d_trace.
px = lagrange_interp(d_trace, px_ev) # interpolating px_ev
cx, remainder = div_polys(px, [-1, 1])  # C(x) = P(x) / (x-1)
assert len(remainder) == 0   # remainder must be zero
```

### -- For the transition constraint

Move on to the transition constraint "Trace\[i\] + Trace\[i+1\] - Trace\[i-2\] = 0". We can apply the same method we did with the input constraint to the transition constraint. The only difference is the transition requires more constraints. As *Trace* is an array of 8 numbers and a constraint involves three elements, it would yield 6 transition constraints. (i.e., Trace\[i\]+Trace\[i+1\]-Trace\[i-2\] where 0&lt;=i&lt;6. "i=6" will result in out-of-index)

1. `P(x) = T(x) + T(x*g) - T(x*g^2)` : P(x) represents the transition constraint.
    
2. `P(x) = C(x) * D(x)` : rephrase it with two polynomials.
    
3. `P(x) = C(x) * ((x-g^0)*(x-g^1)...*(x-g^5))` : P(x) must be "zero" at the first six x-coordinates.
    
4. `C(x) = P(x) / D(x)` : as long as the transition constraint is held, this equation will end up with no remainder.
    

One thing to note here is we need an *adjustment degree*. `px_ev = [Trace[i]+Trace[i+1]-Trace[i+2] for i in range(d_trace_len-2)]` : px\_ev (transition constraint evaluations) will end up with an array full of zero if *Trace* is not corrupted. Then, interpolating px\_ev (P(x)) and doing polynomial division with D(x) would go wrong because deg(P(x)) is less than deg(D(x)). So we have to lift deg(P(x)) up to larger than deg(D(x)). The pseudo-code for it would look like this:

```python
px_ev = [Trace[i]+Trace[i+1]-Trace[i+2] for i in range(d_trace_len-2)]
px = lagrange_interp(d_trace[:d_trace_len-2], px_ev)  # interpolating
px = mul_polys(px, [0, 0, 0, 0, 0, 0, 0, 0, 1])  # px = px * x^8. x^8 is to lift up the degree of px. (i.e., adjustment degree)
dx = mul_polys(....)  # dx = ((x-g^0)*(x-g^1)...*(x-g^5))
cx, remainder = div_polys(px, dx)
assert len(remainder) == 0
```

To this point, I've not used any other domain (*d\_lde* and *d\_ev*) than *d\_trace* for the sake of simplicity. However, in reality, computing constraint evaluations are performed under *d\_ev* and work on *d\_lde* instead of *d\_trace*. (will not discuss here)

### -- Adjust it to low-degree testing (KEY QUESTION!!)

I've used a remainder check to verify all constraints are properly held. But, what the FRI's low-degree testing employs to check constraints is "low-degree check" not "remainder check". So, we need to turn transition constraint evaluations into a suitable form for low-degree testing. Let's revisit the above code snippet: `px_ev = [Trace[i]+Trace[i+1]-Trace[i+2] for i in range(d_trace_len-2)]` will result in an array full of zero, which in turn leads to `px = 0`. This zero polynomial would get in trouble when multiplying with the adjustment degree. To get around this practical issue, I'll take *d\_lde* as a working domain.

```python
input_list = []
for i in range(0, len(d_lde) - 2*blowup, 2):
    input_list.append((d_lde[i], d_lde[i+blowup], d_lde[i+blowup*2]))  # gather values from d_lde
px_ev = [x[0]+x[1]-x[2] for x in input_list]
px = lagrange_interp(d_trace[:len(px_ev)], px_ev)  # interpolating

```
