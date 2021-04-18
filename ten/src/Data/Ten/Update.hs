-- Copyright 2021 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- | Extends 'Representable10' with support for modifying elements.

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.Ten.Update (Update10(..), ix10) where

import Data.Coerce (coerce)
import Data.Functor ((<&>))
import Data.Kind (Type)
import GHC.Generics
         ( Generic1(..)
         , (:*:)(..)
         , M1(..), Rec1(..), U1(..)
         )

import Data.Wrapped (Wrapped1(..))

import Data.Ten.Ap (Ap10(..))
import Data.Ten.Applicative (Applicative10(..))
import Data.Ten.Field (Field10(..))
import Data.Ten.Representable (Representable10(..), GTabulate10(..))

class Representable10 f => Update10 (f :: (k -> Type) -> Type) where
  -- | Modify an @f m@ at a given index.
  over10 :: Rep10 f a -> (m a -> m a) -> f m -> f m

-- | Update an @f m@ at a given index.
update10 :: Update10 f => Rep10 f a -> m a -> f m -> f m
update10 i = over10 i . const

-- | A 'Control.Lens.Lens' to the field identified by a given 'Rep10'.
--
-- @
--     ix10 :: Update10 f => Rep10 f a -> Lens' (f m) (m a)
-- @
ix10
  :: (Update10 f, Functor g)
  => Rep10 f a -> (m a -> g (m a)) -> f m -> g (f m)
ix10 i f = \fm -> f (index10 fm i) <&> \fma -> update10 i fma fm

class GUpdate10 (rec :: (k -> Type) -> Type) where
  gsetters10
    :: (forall a. (forall m. (m a -> m a) -> rec m -> rec m) -> r a)
    -> rec r

instance GUpdate10 U1 where
  gsetters10 _ = U1
  {-# INLINE gsetters10 #-}

instance Update10 rec => GUpdate10 (Rec1 rec) where
  gsetters10 r = Rec1 $ tabulate10 $
    \i -> r (\f -> Rec1 . over10 i f . unRec1)
  {-# INLINE gsetters10 #-}

instance GUpdate10 rec => GUpdate10 (M1 k i rec) where
  gsetters10 r = M1 $ gsetters10 (\s -> r $ \f -> M1 . s f . unM1 )
  {-# INLINE gsetters10 #-}

instance GUpdate10 (Ap10 a) where
  gsetters10 r = Ap10 $ r coerce
  {-# INLINE gsetters10 #-}

mapStarFst :: (f m -> f m) -> (f :*: g) m -> (f :*: g) m
mapStarFst h (f :*: g) = h f :*: g

mapStarSnd :: (g m -> g m) -> (f :*: g) m -> (f :*: g) m
mapStarSnd h (f :*: g) = f :*: h g

instance (GUpdate10 f, GUpdate10 g) => GUpdate10 (f :*: g) where
  gsetters10 r = fsetters :*: gsetters
   where
    fsetters = gsetters10 $ \s -> r $ mapStarFst . s
    gsetters = gsetters10 $ \s -> r $ mapStarSnd . s
  {-# INLINE gsetters10 #-}

{-
instance (GUpdate10 f, GUpdate10 g) => GUpdate10 (f :.: g) where
  gsetters10 r = Comp1 $
    gsetters00 $ \ s0 ->
    gsetters10 $ \ s1 ->
    r $ \f -> Comp1 . s0 (s1 f) . unComp1
  {-# INLINE gsetters10 #-}
  -}

newtype FieldSetter10 rec a = FS10
  { runFS10 :: forall m. (m a -> m a) -> rec m -> rec m }

setters10 :: (Generic1 f, GUpdate10 (Rep1 f)) => f (FieldSetter10 f)
setters10 = to1 $ gsetters10 (\overI -> FS10 $ \f -> to1 . overI f . from1)

instance ( Generic1 f
         , Applicative10 (Rep1 f), GTabulate10 (Rep1 f), GUpdate10 (Rep1 f)
         )
      => Update10 (Wrapped1 Generic1 f) where
  over10 =
    \i f (Wrapped1 fm) -> Wrapped1 $ runFS10 (getField10 i setters) f fm
   where
     -- Superstition-based optimization: try to make GHC specialize 'setters10'
     -- to @f@ exactly once per instance of 'Update10'.
     setters :: f (FieldSetter10 f)
     setters = setters10
