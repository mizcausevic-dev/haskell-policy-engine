{-# LANGUAGE DeriveGeneric    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase        #-}

-- | A small declarative policy DSL. Policies are an algebraic data type
-- with three constructors:
--
--   * 'Allow'   — admit the request unconditionally
--   * 'Deny'    — reject with a textual reason
--   * 'When'    — branch on a 'Predicate'
--
-- Predicates compose via 'PAnd', 'POr', and 'PNot'. The evaluator is
-- a pure function over 'Input', so policies can be evaluated, JSON-
-- encoded, and round-tripped without any IO.
module Policy
  ( -- * Types
    Policy(..)
  , Predicate(..)
  , Input(..)
  , Decision(..)
    -- * Evaluation
  , evaluate
    -- * Convenience
  , allow
  , deny
  , whenPred
  ) where

import           Data.Aeson
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Text       (Text)
import qualified Data.Text       as T
import           GHC.Generics    (Generic)

-- | A request the policy is evaluated against.
data Input = Input
  { country :: Text
  , buckets :: Map Text Int
  } deriving (Show, Eq, Generic)

instance ToJSON Input
instance FromJSON Input

-- | The outcome of evaluating a 'Policy'.
data Decision
  = DAllow
  | DDeny Text
  deriving (Show, Eq, Generic)

instance ToJSON Decision where
  toJSON = \case
    DAllow      -> object ["decision" .= ("allow" :: Text)]
    DDeny reason -> object ["decision" .= ("deny" :: Text), "reason" .= reason]

instance FromJSON Decision where
  parseJSON = withObject "Decision" $ \o -> do
    tag <- o .: "decision"
    case tag :: Text of
      "allow" -> pure DAllow
      "deny"  -> DDeny <$> o .: "reason"
      other   -> fail $ "unknown decision tag: " <> T.unpack other

-- | Top-level policy AST.
data Policy
  = Allow
  | Deny Text
  | When Predicate Policy Policy
  deriving (Show, Eq, Generic)

instance ToJSON Policy where
  toJSON = \case
    Allow            -> object ["kind" .= ("allow" :: Text)]
    Deny reason       -> object ["kind" .= ("deny" :: Text), "reason" .= reason]
    When p ifT ifF    -> object
                          [ "kind" .= ("when" :: Text)
                          , "predicate" .= p
                          , "then" .= ifT
                          , "else" .= ifF
                          ]

instance FromJSON Policy where
  parseJSON = withObject "Policy" $ \o -> do
    tag <- o .: "kind"
    case tag :: Text of
      "allow" -> pure Allow
      "deny"  -> Deny <$> o .: "reason"
      "when"  -> When <$> o .: "predicate" <*> o .: "then" <*> o .: "else"
      other   -> fail $ "unknown policy kind: " <> T.unpack other

-- | Predicates compose conjunctively (PAnd), disjunctively (POr), and
-- under negation (PNot). Atomic predicates inspect the input's country
-- or bucket values.
data Predicate
  = PAnd [Predicate]
  | POr  [Predicate]
  | PNot Predicate
  | PCountryIn [Text]
  | PBucketBelow Text Int
  | PBucketAtLeast Text Int
  deriving (Show, Eq, Generic)

instance ToJSON Predicate where
  toJSON = \case
    PAnd ps           -> object ["op" .= ("and" :: Text), "args" .= ps]
    POr ps            -> object ["op" .= ("or" :: Text),  "args" .= ps]
    PNot p            -> object ["op" .= ("not" :: Text), "arg" .= p]
    PCountryIn cs     -> object ["op" .= ("country_in" :: Text), "countries" .= cs]
    PBucketBelow b n  -> object ["op" .= ("bucket_below" :: Text), "bucket" .= b, "value" .= n]
    PBucketAtLeast b n -> object ["op" .= ("bucket_at_least" :: Text), "bucket" .= b, "value" .= n]

instance FromJSON Predicate where
  parseJSON = withObject "Predicate" $ \o -> do
    op <- o .: "op"
    case op :: Text of
      "and"             -> PAnd <$> o .: "args"
      "or"              -> POr  <$> o .: "args"
      "not"             -> PNot <$> o .: "arg"
      "country_in"      -> PCountryIn <$> o .: "countries"
      "bucket_below"    -> PBucketBelow <$> o .: "bucket" <*> o .: "value"
      "bucket_at_least" -> PBucketAtLeast <$> o .: "bucket" <*> o .: "value"
      other             -> fail $ "unknown predicate op: " <> T.unpack other

-- | Run a policy against an input. Total: never throws.
evaluate :: Policy -> Input -> Decision
evaluate Allow _       = DAllow
evaluate (Deny r) _    = DDeny r
evaluate (When p t f) i
  | matches p i        = evaluate t i
  | otherwise          = evaluate f i

matches :: Predicate -> Input -> Bool
matches (PAnd ps) i           = all (`matches` i) ps
matches (POr  ps) i           = any (`matches` i) ps
matches (PNot p)  i           = not (matches p i)
matches (PCountryIn cs) i     = country i `elem` cs
matches (PBucketBelow b n) i  = case Map.lookup b (buckets i) of
                                  Just v  -> v < n
                                  Nothing -> False
matches (PBucketAtLeast b n) i = case Map.lookup b (buckets i) of
                                  Just v  -> v >= n
                                  Nothing -> False

-- | Convenience smart constructors.
allow :: Policy
allow = Allow

deny :: Text -> Policy
deny = Deny

whenPred :: Predicate -> Policy -> Policy -> Policy
whenPred = When
