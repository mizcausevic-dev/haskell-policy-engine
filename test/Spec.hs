{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import qualified Data.Aeson as A
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import           Test.Hspec
import           Test.QuickCheck

import           Policy

-- Sample policy reused across tests.
samplePolicy :: Policy
samplePolicy =
  whenPred (PCountryIn ["KP", "IR"])
    (deny "geo_blocked")
    (whenPred (PBucketAtLeast "rate" 1)
       allow
       (deny "rate_limit_exhausted"))

main :: IO ()
main = hspec $ do

  describe "evaluate" $ do
    it "Allow always allows" $
      evaluate Allow (Input "US" Map.empty) `shouldBe` DAllow

    it "Deny always denies with the given reason" $
      evaluate (deny "nope") (Input "US" Map.empty)
        `shouldBe` DDeny "nope"

    it "country block fires" $
      evaluate samplePolicy (Input "KP" (Map.fromList [("rate", 5)]))
        `shouldBe` DDeny "geo_blocked"

    it "rate exhaustion fires" $
      evaluate samplePolicy (Input "US" (Map.fromList [("rate", 0)]))
        `shouldBe` DDeny "rate_limit_exhausted"

    it "safe country + budget allows" $
      evaluate samplePolicy (Input "US" (Map.fromList [("rate", 10)]))
        `shouldBe` DAllow

    it "case-sensitive country comparison (text equality)" $
      evaluate samplePolicy (Input "kp" (Map.fromList [("rate", 5)]))
        `shouldBe` DAllow  -- lowercase "kp" is NOT in the blocked list

  describe "JSON round-trip" $ do
    it "policy round-trips through JSON" $ do
      let json = A.encode samplePolicy
      case A.eitherDecode json of
        Right (p :: Policy) -> p `shouldBe` samplePolicy
        Left err            -> expectationFailure $ "decode error: " <> err

    it "decision round-trips through JSON" $ do
      let d = DDeny "geo_blocked"
      case A.eitherDecode (A.encode d) of
        Right d' -> d' `shouldBe` d
        Left err -> expectationFailure $ "decode error: " <> err

  describe "Predicate combinators" $ do
    it "PAnd is True iff all sub-predicates are True" $
      let p = PAnd [PCountryIn ["US"], PBucketAtLeast "rate" 5]
          i = Input "US" (Map.fromList [("rate", 10)])
      in evaluate (whenPred p Allow (deny "no")) i `shouldBe` DAllow

    it "POr is True iff any sub-predicate is True" $
      let p = POr [PCountryIn ["KP"], PBucketAtLeast "rate" 5]
          i = Input "US" (Map.fromList [("rate", 10)])
      in evaluate (whenPred p Allow (deny "no")) i `shouldBe` DAllow

    it "PNot inverts" $
      let p = PNot (PCountryIn ["KP"])
          i = Input "US" Map.empty
      in evaluate (whenPred p Allow (deny "no")) i `shouldBe` DAllow

  describe "Properties" $ do
    it "evaluate is total over generated Allow/Deny policies" $
      property $ \(reasonStr :: String) ->
        let r = if null reasonStr then "default" else T.pack reasonStr
            inp = Input "US" Map.empty
            dec = evaluate (deny r) inp
        in case dec of
             DAllow   -> False
             DDeny _  -> True

    it "Allow ignores the input" $
      property $ \((c, n) :: (String, Int)) ->
        evaluate Allow (Input (T.pack c) (Map.fromList [("rate", n)])) == DAllow
