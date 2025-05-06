---
title: "Exploring a n-th primitive root of unity over finite field for software engineers"
date: 2022-11-21
layout: post
---

## Introduction

In this article, I’ll talk about a n-th primitive root of unity used in number theory in math, especially in the context of a finite field. I’m a software engineer, not a mathematician so I want to see this in the eyes of software engineers and hope you can find this article useful if you are a software engineer who doesn’t feel comfortable in math.

## What is Domain?

Before getting into the main part-- what is a n-th primitive root of unity?-- I want to say about what domain is. We can think of a domain as a set of inputs (and outputs) for a function. Say there is a function *f(x)* where 1<=x<=9 (and 1<=*f(x)*<=9) . Then, The domain for *f(x)* is {1,2,…,9}. This is what basically domain is. Simple as that. When it comes to programming, you can simply imagine a software function `fn add(a: uint32, b: uint32) { return a + b}`. For `add(a, b)`, the input values, a, b, are in the domain of uint32.

What if we want a smaller domain for `add(a, b)` than uint32? The finite field will help us do that. Take a prime number (7 for example) and add a mod operation into add() like `fn add(a: uint32, b: uint32) { return (a + b) % 7 }`. With this prime finite field, the size of the domain of `add()` would reduce from uint32 to 7 as a mod 7 always falls in 0~6. (See [my previous post](https://jinb-park.github.io/2022/09/06/finite-field-for-developers.html) if you want to know more about finite field)

## A primitive n-th root of unity

First of all, we have to know the definition of a n-th root of unity. And then we’ll see several requirements for a n-th root of unity to be a primitive one. In this section, I’ll just introduce their definitions, not what they mean in the context of domain and programming, which will be followed by the next section.

Suppose that we’re working on a prime finite field that takes a prime number *P* (you can think of this as modulus) and we want to get a domain whose size is *N*. If W^N = 1, W can be called a *N*-th root of unity.

For this *W* to be a primitive *N*-th root of unity, it requires the following rules must be satisfied.

- **R1**:  *W^N = 1*  (this is common to both a *N*-th and a primitive *N*-th root of unity)
- **R2**:  *N* is a unit in *P*  (i.e., *N* must be one of *P*. For example, in *P=7*, *N* must be between 1 and 6.)
- **R3**:  *N* divides *P-1*
- **R4**:  for every prime divisor *T* of *N*, *W^(N/T) != 1*  (e.g., N = 12 = 2*2*3, prime divisor = 2, 3)

We’ll discuss these rules in the next section with a hands-on example.

## What does “a primitive n-th root of unity” mean in a domain?

First of all, let’s get to know what “a n-th root of unity” means. To do so, I’ll get into a requirement that "R1: *W^N = 1*". Say that we want to produce a domain whose size is *N* over finite field *P*. Here, we can use *W* (root of unity) as a generator for *P* (See my [previous post](https://jinb-park.github.io/2022/09/06/finite-field-for-developers.html) to know what generator is). Then, its domain will be like,

Domain = { *W^0, W^1, W^2, …, W^(N-1)* }  → this domain is of the length *N* we want. I’ll denote this domain as *D* from now on.

The point is, *D* is a finite and cyclic group, which means *W^N* must get back to *W^0* (1). This is exactly why we should use “R1: *W^N* = 1” to find a n-th root of unity. Another way of speaking about it is **this is one way to generate a domain of the length you want**. 

But, let’s think about one more thing. If what we want to do is just generate a domain of the length *N*, why don’t we just take a set derived from modulus operations with *P*?

I mean, let’s say we want a domain of the length 6, then “mod 7” can yield *{1,2,…6}* that is what we want. Of course, *{1,2,…6}* equals *{W^0, …W^5} *in the length of the domain. But the elements in the sets are completely different. *“{1,2,…6}”* has just an incremental order by 1 while *{W^0, …W^5}* has an incremental order by square (p.s. generally speaking, this is a property of generator). Having an order by square means a lot to computational optimizations. For example, when we’re going to use FFT (Fast Fourier Transformation) over a finite field, its domain must be in order by square. In short, this way to produce a domain brings speed up to a variety of software so we have to take this approach (root of unity) to fit our programs in fast algorithms.

## A hands-on example

To make everything clear, I’ll show you a few hands-on examples so that you can catch on to how all of it works from software engineers’ perspectives.

### -- Example: In P = 17, N = 16, compute W

Let’s take 3 as *W* first and do this python code, `[pow(3,i)%17 for i in range(17)]`, which will yield `[1, 3, 9, 10, 13, 5, 15, 11, 16, 14, 8, 7, 4, 12, 2, 6, 1]`. And then, check by hand each rule required to be a primitive 16-th root of unity.

- **R1**: *W^N = 1 * → You can see 3^16 = 1 in the result array. Passed.
- **R2**: *N* is a unit in *P*.  → 16 is in a finite field 17. Passed.
- **R3**: *N* divides *P-1* → (17-1) % 16 = 0. Passed.
- **R4**: for every prime divisor *T* of *N*, *W^(N/T) != 1*. → 16=2^4, so 2 is the only prime divisor. 3^(16/2)=16 (!= 1) Passed.

As you can see, 3 is a primitive 16-th root of unity as all requirements are fulfilled. But, I will not stop here but do one more thing. What happens if we take 2 as *W* ? Check it by hand again. A for loop `[pow(2,i)%17 for i in range(17)]` yields `[1, 2, 4, 8, 16, 15, 13, 9, 1, 2, 4, 8, 16, 15, 13, 9, 1]`. We can say 2 is a 16-th root of unity because 2^16 = 1, but cannot say this is a primitive one because 2^(16/2) = 1, which violates R4. What it’s worth noting here is 2 can be a 8-th primitive root of unity because when we change N from 16 to 8, both R1 and R4 get passed. This fact can give us a practical lesson described below.

### -- Lesson: getting domains of a variety of lengths over the same finite field

As shown in the previous example, using 2 as *W* yields a domain of the length 8 which is not equal to *P-1* (16). This practically gives us a lesson that we can get domains of various lengths over the same finite field. Taking one more example, *W=4* can be a primitive 4-th root of unity, which means it generates a domain of the length 4 over the same finite field, *P=17*. In other words, more mathematically speaking, we can think of a root of unity and a generator as not the same ones. (i.e., 2 is not a generator for *P=17* because it doesn’t produce all elements in that *P*.)

## How to quickly determine a primitive n-th root of unity

When you already know what a generator is for a finite field, you’re able to directly point to what a primitive n-th root of unity is through this formula:  w = g^((p-1)/n). (See [this lecture note](https://www.csd.uwo.ca/~mmorenom/CS874/Lectures/Newton2Hensel.html/node9.html) for detailed proofs)

Let me take an example from [Ethereum's research code snippets](https://github.com/ethereum/research/tree/master/mimc_stark) about STARK: `root_of_unity = pow(7, (p-1)//16384, p)` where 7 is a generator for the finite field p and 16384 is what we want the resultant domain size to be. This line of code exactly equals the above formula.

Let’s take one step further. For programmers, it would be common to get your domain size aligned to 2^k, but the previous example uses 16384 which is not aligned. So, how can we get it aligned? The key to doing it is in “R3: N divides P-1”.

Let me give you an example in which “P = 2^128 - 45 \* 2^40 + 1”. Here, P-1 can be divisible by 2^40 and thus divisible by any of between 2^1 and 2^40. It means that in this finite field we can easily have a domain of lengths from 2^1 and 2^40. If we choose a larger *P* that is divisible by a larger value, its domain length can also be larger.

P.S. We simply assume we know a generator. If you wonder how to find a generator, see [this blog post](https://saadquader.wordpress.com/2017/08/25/finding-primitive-roots-of-unity-in-a-finite-field-c-code-using-ntl/).