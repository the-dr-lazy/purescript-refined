module Data.Refined ( module Data.Refined.Error
                    , module Data.Refined.Internal
                    , module Data.Refined.Predicate
                    , Refined(..)
                    , refine
                    , unsafeRefine
                    , unrefine
                    ) where

import Test.QuickCheck.Gen
import Prelude
import Control.Monad.Except (except)
import Data.Argonaut (class EncodeJson)
import Data.Argonaut.Decode (class DecodeJson, decodeJson, JsonDecodeError(..))
import Data.Bifunctor (lmap)
import Data.Either (Either, isRight)
import Data.Generic.Rep (class Generic)
import Data.Ord (class Ord)
import Data.Refined.Error (RefinedError(..))
import Data.Refined.Internal (These(..), fromInt)
import Data.Refined.Predicate (class Predicate, And, EqualTo, From, FromTo, GreaterThan, IdPred, LessThan, Negative, NonEmpty, NonNegative, NonZero, Not, NotEqualTo, Or, Positive, SizeEqualTo, SizeGreaterThan, SizeLessThan, To, ZeroToOne, validate)
import Data.Typelevel.Undefined (undefined)
import Foreign as Foreign
import Foreign.Class as Foreign
import Test.QuickCheck (class Arbitrary, arbitrary)

newtype Refined p x
  = Refined x

derive newtype instance eqRefined 
  :: (Eq x) => Eq (Refined p x)
derive newtype instance showRefined 
  :: (Show x) => Show (Refined p x)
derive newtype instance ordRefined
  :: (Ord x) => Ord (Refined p x)
derive instance genericRefined
  :: Generic (Refined p x) _

-- | for decoding we first decode the thing inside, then run our predicate on it
instance decodeJsonRefined 
  :: (DecodeJson x, Show x, Predicate p x) 
  => DecodeJson (Refined p x) where
  decodeJson a = do
     val <- decodeJson a
     (refineJson val :: Either JsonDecodeError (Refined p x))

-- | for encoding we just want to strip away the outside layer and use whatever
-- | is inside
derive newtype instance encodeJsonRefined 
  :: (EncodeJson x) => EncodeJson (Refined p x)

-- | for decoding we first decode the thing inside, then run our predicate on it
instance decodeForeignRefined
  :: (Foreign.Decode x, Show x, Predicate p x)
  => Foreign.Decode (Refined p x) where
  decode a = Foreign.decode a >>= refineForeign

-- | for encoding we just want to strip away the outside layer and use whatever
-- | is inside
derive newtype instance endcodeForeignRefined
  :: (Foreign.Encode x) => Foreign.Encode (Refined p x)

-- | create an Arbitrary instance by randomly throwing values against the wall
-- | until something sticks
instance arbitraryRefined 
  :: (Arbitrary a, Predicate p a)
  => Arbitrary (Refined p a) where
  arbitrary 
    = Refined <$> suchThat (arbitrary :: Gen a) (isRight <<< (refine :: a ->
      Either (RefinedError a) (Refined p a)))

-- used by decode json for it's errors
refineJson 
  :: forall p x. (Predicate p x)
  => (Show x) 
  => x 
  -> Either JsonDecodeError (Refined p x)
refineJson x = lmap (TypeMismatch <<< show) (refine x)

-- used by foreign decode for it's errors
refineForeign
  :: forall p x. (Predicate p x)
  => (Show x)
  => x
  -> Foreign.F (Refined p x)
refineForeign = except <<< lmap (pure <<< Foreign.ForeignError <<< show) <<< refine

-- the regular way in which one would turn a value into a Refined value
refine 
  :: forall p x. (Predicate p x) 
  => x 
  -> Either (RefinedError x) (Refined p x)
refine x = do
  Refined <$> validate (undefined :: p) x

-- the Bad Boy way to make a Refined (for testing etc)
unsafeRefine 
  :: forall p x. (Predicate p x) 
   => x 
   -> (Refined p x)
unsafeRefine x = Refined x

-- Let's get that value out and use it for something useful
unrefine 
  :: forall p x. Refined p x 
   -> x
unrefine (Refined x) = x
