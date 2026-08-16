{-# LANGUAGE CPP #-}
module SAT(
           SATState,
           initSATState,
           checkBiImplication,
           isConstExpr,
           checkEq,
           checkNotEq
          ) where

import Error(ErrorHandle)
import Flags
import ASyntax

import qualified AExpr2CVC5 as CVC5
         (CState, initCState, checkBiImplication, isConstExpr,
          checkEq, checkNotEq)

-- -------------------------

-- The solver state (cvc5 is the only backend)
type SATState = CVC5.CState

initSATState :: String -> ErrorHandle -> Flags -> Bool -> [ADef] -> [AVInst] ->
                IO SATState
initSATState str _errh flags doHardFail ds avis =
    CVC5.initCState str flags doHardFail ds avis []

-- -------------------------

checkBiImplication :: SATState -> AExpr -> AExpr -> IO ((Bool, Bool), SATState)
checkBiImplication = CVC5.checkBiImplication

isConstExpr :: SATState -> AExpr -> IO (Maybe Bool, SATState)
isConstExpr = CVC5.isConstExpr

checkEq :: SATState -> AExpr -> AExpr -> IO (Maybe Bool, SATState)
checkEq = CVC5.checkEq

checkNotEq :: SATState -> AExpr -> AExpr -> IO (Maybe Bool, SATState)
checkNotEq = CVC5.checkNotEq

-- -------------------------
