{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | CLI demo: assemble a policy, encode to JSON, decode back,
-- evaluate against three example inputs.
module Main where

import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Data.Map.Strict as Map

import Policy

samplePolicy :: Policy
samplePolicy =
  whenPred (PCountryIn ["KP", "IR"])
    (deny "geo_blocked")
    (whenPred (PBucketAtLeast "rate" 1)
       (whenPred (PCountryIn ["DE", "FR", "IT"])
          (deny "audit_required_for_eu_traffic")
          allow)
       (deny "rate_limit_exhausted"))

main :: IO ()
main = do
  putStrLn "== policy as JSON =="
  BL.putStrLn (A.encode samplePolicy)

  let inputs =
        [ ("US-allow",       Input "US" (Map.fromList [("rate", 10)]))
        , ("KP-geo-deny",    Input "KP" (Map.fromList [("rate", 10)]))
        , ("US-rate-deny",   Input "US" (Map.fromList [("rate", 0)]))
        , ("DE-eu-audit",    Input "DE" (Map.fromList [("rate", 5)]))
        ]
  putStrLn "\n== evaluations =="
  mapM_ (\(name, inp) ->
           putStrLn $ name <> ": " <> show (evaluate samplePolicy inp))
        inputs

  putStrLn "\n== round-trip via JSON =="
  let json = A.encode samplePolicy
  case A.eitherDecode json of
    Left err -> putStrLn $ "decode error: " <> err
    Right (p :: Policy) -> do
      let same = evaluate p (Input "US" (Map.fromList [("rate", 10)]))
      putStrLn $ "decoded policy on US-allow input: " <> show same
