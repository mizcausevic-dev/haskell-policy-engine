# haskell-policy-engine

A small **type-safe policy DSL in Haskell** with a pure evaluator, an Aeson JSON codec, and Hspec + QuickCheck tests.

Policies are an algebraic data type:

```haskell
data Policy
  = Allow                                -- admit unconditionally
  | Deny  Text                           -- reject with a textual reason
  | When  Predicate Policy Policy        -- branch on a predicate
```

Predicates compose via `PAnd`, `POr`, `PNot`, plus atoms for country membership and bucket comparisons (`PCountryIn`, `PBucketBelow`, `PBucketAtLeast`). The `evaluate` function is total — no IO, no exceptions — so policies are trivially fuzzable and reproducible.

## Quickstart

```bash
stack build
stack test
stack exec policy-cli
```

`stack exec policy-cli` output:

```
== policy as JSON ==
{"kind":"when","predicate":{"op":"country_in","countries":["KP","IR"]}, ...}

== evaluations ==
US-allow:     DAllow
KP-geo-deny:  DDeny "geo_blocked"
US-rate-deny: DDeny "rate_limit_exhausted"
DE-eu-audit:  DDeny "audit_required_for_eu_traffic"

== round-trip via JSON ==
decoded policy on US-allow input: DAllow
```

## Library usage

```haskell
import qualified Data.Map.Strict as Map
import           Policy

myPolicy :: Policy
myPolicy =
  whenPred (PCountryIn ["KP", "IR"])
    (deny "geo_blocked")
    (whenPred (PBucketAtLeast "rate" 1)
       allow
       (deny "rate_limit_exhausted"))

main :: IO ()
main = do
  let inp = Input "US" (Map.fromList [("rate", 10)])
  print (evaluate myPolicy inp)   -- DAllow
```

## JSON serialization

Aeson handles encoding / decoding for `Policy`, `Predicate`, `Decision`, and `Input`. The wire format uses tagged objects:

```json
{
  "kind": "when",
  "predicate": { "op": "country_in", "countries": ["KP", "IR"] },
  "then": { "kind": "deny", "reason": "geo_blocked" },
  "else": { "kind": "allow" }
}
```

## Tests

Hspec test suite covers:

- Allow / Deny base cases
- Country block / rate exhaustion / safe-country happy path
- Text equality (case-sensitivity disclosure)
- JSON round-trip for `Policy` and `Decision`
- `PAnd` / `POr` / `PNot` combinator semantics
- QuickCheck properties: `evaluate` is total over generated `Deny` policies; `Allow` ignores the input

## Why this design?

A free-monad EDSL or a final-tagless interpreter gives more abstract power, but the closed sum-type `Policy` is **easier to serialize, easier to teach, and easier to audit** — which is what an access-control policy DSL actually needs.

## Dependencies

- `aeson` ≥ 2.0 — JSON codec
- `containers` ≥ 0.6 — `Data.Map.Strict`
- `text`, `bytestring` — stdlib
- `hspec`, `QuickCheck` — test-only

## License

AGPL-3.0.

---

**Connect:** [LinkedIn](https://www.linkedin.com/in/mirzacausevic/) · [Kinetic Gain](https://kineticgain.com) · [Medium](https://medium.com/@mizcausevic/) · [Skills](https://mizcausevic.com/skills/)
