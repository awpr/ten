-- Copyright 2018-2021 Google LLC
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

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE PolyKinds #-}

module Data.Ten.Ap (Ap10(..)) where

import Data.Kind (Type)
import GHC.Generics (Generic)

import Control.DeepSeq (NFData)
import Data.Default.Class (Default(..))
import Data.Portray (Portray)
import Text.PrettyPrint.HughesPJClass (Pretty)

-- | A 'Functor10' made by applying the argument to a fixed type.
newtype Ap10 (a :: k) (f :: k -> Type) = Ap10 { unAp10 :: f a }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (Default, Pretty, Portray)

instance (NFData a, NFData (f a)) => NFData (Ap10 a f)