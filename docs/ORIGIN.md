# Why We Built This

**haskell-policy-engine** started from a recurring problem in identity governance: teams had more signal than operational clarity. That difference between visibility and usability kept showing up under pressure.

The recurring pressure in this space showed up around identity sprawl, tenant-boundary mistakes, and access-review workflows that are technically complete but poorly explained. In practice, that meant teams could collect logs, metrics, workflow state, documents, or events and still not have a good answer to the hardest questions: what is drifting, what matters first, who owns the next move, and what evidence supports that move? Once a system reaches that point, the problem is no longer only technical. It becomes operational.

That is why **haskell-policy-engine** was built the way it was. The repo is a deliberate attempt to model a real operating layer for IAM, platform security, compliance, and internal platform teams. It is not just trying to present data attractively or prove that a stack can be wired together. It is trying to show what happens when evidence, prioritization, and next-best action are treated as first-class product concerns.

Existing tools helped with adjacent workflows. IGA suites, ticket approvals, and access review campaigns covered storage, reporting, scanning, or execution in pieces. What they still missed was a fast, legible control layer for access reasoning at the moment decisions are made. That left operators reconstructing the story manually at exactly the moment they needed clarity.

That shaped the design philosophy:

- **operator-first** so the riskiest or most time-sensitive signal is surfaced early
- **decision-legible** so the logic behind a recommendation can be understood by humans under pressure
- **review-friendly** so the repo supports discussion, governance, and iteration instead of hiding the reasoning
- **CI-native** so checks and narratives can live close to the build and change process

This repo also avoids trying to be a vague platform for everything. Its value comes from being opinionated about a real problem: Type-safe policy DSL in Haskell. Algebraic data type Policy = Allow | Deny | When; predicates compose via And/Or/Not; pure total evaluator; Aeson JSON codec; Hspec + QuickCheck tests. Functional purity flex for the agent-governance theme.

What comes next is practical. The roadmap is about richer entitlement evidence, clearer review context, and stronger ties into adjacent platform controls. The long-term value of **haskell-policy-engine** is that it makes that operating layer concrete enough to review, improve, and trust.