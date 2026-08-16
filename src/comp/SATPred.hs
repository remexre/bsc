module SATPred(
  SATPredState,
  initSATPredState,
  solvePred
  ) where

import Flags
import Pred

import qualified Pred2CVC5 as CVC5
         (CState, initCState, solvePred)

-- -------------------------

-- The solver state (cvc5 is the only backend)
type SATPredState = CVC5.CState

initSATPredState :: Flags -> IO SATPredState
initSATPredState _flags = CVC5.initCState

-- -------------------------

solvePred :: SATPredState -> [Pred] -> Pred -> IO (Maybe Pred, SATPredState)
solvePred = CVC5.solvePred

-- -------------------------
