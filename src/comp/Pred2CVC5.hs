module Pred2CVC5(
       CState,
       initCState,
       solvePred
) where

import Control.Monad(when)
import Control.Monad.State(StateT, liftIO, gets, get, put, runStateT)
import qualified Data.Map as M
import qualified CVC5 as C

import ErrorUtil(internalError)
--import Flags
import PFPrint
import Id
import PreIds
import CType
import Type
import Pred
import Util(itos)

import Debug.Trace(traceM)
import IOUtil(progArgs)

traceTest :: Bool
traceTest = "-trace-smt-test" `elem` progArgs

traceConv :: Bool
traceConv = "-trace-smt-conv" `elem` progArgs

-- -------------------------

data CState =
    CState {
               context       :: C.Context,
               --flags         :: Flags,

               -- source of unique identifiers
               unknownId     :: Integer,

               -- all BSV types will be represented by one type in cvc5,
               -- so keep a handle to the type
               intType       :: C.Type,

               -- a map from types to their converted form
               -- (this is used both to avoid duplicate conversion
               -- and as a list of possible terms for solving)
               typeCExprMap   :: M.Map Type (C.Expr, [C.Expr])
              }

type CM = StateT CState IO

-- represent numeric types as 32-bit vectors
-- (since that provides a division operator and log/exp via shifting)
intWidth :: (Integral t) => t
intWidth = 32

-- -------------------------

initCState :: IO CState
initCState = do
  ctx <- liftIO $ C.mkContext
  int_ty <- liftIO $ C.mkBitVectorType ctx intWidth
  return (CState { context = ctx,
                   --flags = flags,
                   unknownId = 0,
                   intType = int_ty,
                   typeCExprMap = M.empty
                 })

-- -------------------------

{-
-- XXX We'll eventually want to test that user-given provisos are satisfiable
-- XXX and give a user error if not.  We'll also want to test, before reporting
-- XXX that additional provisos are needed, that the additional provisos are
-- XXX satisfiable.

-- Check if a set of predicates is consistent

checkPreds :: CState -> [Pred] -> IO ([EMsg], CState)
checkPreds s ps = runStateT (checkPredsM ps) s

checkPredsM :: [Pred] -> CM [EMsg]
checkPredsM ps = do
  ctx <- gets context

  -- push a new context, so we can cleanly retract the work when we're done
  liftIO $ C.ctxPush ctx

  -- assert the given provisos
  mapM_ assertPred ps

  -- check if there exists a solution
  sat <- checkSAT

  -- pop the context
  liftIO $ C.ctxPop ctx

  -- if there is no solution, report an error to the user
  if (sat /= Just True)
    then reportMinUnsatPreds [] ps
    else return []


reportMinUnsatPreds :: [Pred] -> [Pred] -> CM [EMsg]
reportMinUnsatPreds qs [] =
  -- XXX "satisfy" will need to take a position and plumb it to "reducePred"
  return [(noPosition, EGeneric ("unsat preds: " ++ ppReadable qs))]

reportMinUnsatPreds qs (p:ps) = do
  ctx <- gets context

  -- push a new context, so we can cleanly retract the work when we're done
  liftIO $ C.ctxPush ctx

  -- assert all the provisos besides "p"
  mapM_ assertPred (qs ++ ps)

  -- check if there exists a solution
  sat <- checkSAT

  -- pop the context
  liftIO $ C.ctxPop ctx

  -- if there is still no solution, then drop "p" else keep it
  if (sat /= Just True)
    then reportMinUnsatPreds qs ps
    else reportMinUnsatPreds (p:qs) ps
-}

-- -------------------------

-- XXX should this take the BVS and DVS?

solvePred :: CState -> [Pred] -> Pred -> IO (Maybe Pred, CState)
solvePred s ps p = runStateT (solvePredM ps p) s

solvePredM :: [Pred] -> Pred -> CM (Maybe Pred)
solvePredM ps p = do
  ctx <- gets context

  when traceTest $ traceM ("solvePred: " ++ ppReadable p)

  -- check that the pred is one that we handle, and if so then
  -- construct p as an inequality (along with its additional assertions)
  m_yneq <- genPredInequality p
  case m_yneq of
    Nothing -> do
      -- the pred is not of the form that we can handle
      when traceTest $ traceM("solvePred: not handled")
      return Nothing
    Just (yneq, as) -> do

      -- first make sure that the preds have at least one solution
      is_sat <- do
          -- push a new context,
          -- so we can cleanly retract the work when we're done
          liftIO $ C.ctxPush ctx
          -- assert the given provisos
          mapM_ assertPred (p:ps)
          -- check if there exists a solution
          sat <- checkSAT
          -- pop the context
          liftIO $ C.ctxPop ctx
          return (sat == Just True)

      -- if there is no solution, return the pred unsatisfied
      -- (if an error needs to be reported, it will be reported later)
      if (not is_sat)
        then do when traceTest $ traceM("solvePred: not satisfiable")
                return Nothing
        else do

          -- push a new context,
          -- so we can cleanly retract the work when we're done
          liftIO $ C.ctxPush ctx
          -- assert the given provisos
          mapM_ assertPred ps

          -- XXX for now, we only resolve provisos where no substitution is learned

          -- assert the inequality and associated assumptions
          mapM_ (liftIO . C.assert ctx) (yneq:as)
          -- check if there exists a solution
          sat <- checkSAT
          -- if it is satisfiable, then the equality does not hold
          let res = case sat of
                      Just False -> Just p
                      _ -> Nothing
          -- retract the assertions
          liftIO $ C.ctxPop ctx
          when traceTest $
              case res of
                Nothing -> traceM ("solvePred: unresolved: " ++ ppReadable p)
                Just _  -> traceM ("solvePred: resolved: " ++ ppReadable p)
          return res


genPredInequality :: Pred -> CM (Maybe (C.Expr, [C.Expr]))
genPredInequality p@(IsIn c [t1, t2]) | classId c == idNumEq = do
  when traceTest $ traceM("pred: " ++ ppReadable p)
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  ynp <- mkNEq yt1 yt2
  return $ Just (ynp, as1 ++ as2)
genPredInequality p@(IsIn c [t1, t2, t3]) | classId c == idAdd = do
  when traceTest $ traceM("pred: " ++ ppReadable p)
  (yt3, as3) <- convType2CExpr t3
  (yadd, as12) <- convType2CExpr (TAp (TAp tAdd t1) t2)
  ynp <- mkNEq yadd yt3
  return $ Just (ynp, as3 ++ as12)
genPredInequality p@(IsIn c [t1, t2, t3]) | classId c == idMul = do
  when traceTest $ traceM("pred: " ++ ppReadable p)
  (yt3, as3) <- convType2CExpr t3
  (ymul, as12) <- convType2CExpr (TAp (TAp tMul t1) t2)
  ynp <- mkNEq ymul yt3
  return $ Just (ynp, as3 ++ as12)
genPredInequality p@(IsIn c [t1, t2, t3]) | classId c == idMax = do
  when traceTest $ traceM("pred: " ++ ppReadable p)
  (yt3, as3) <- convType2CExpr t3
  (ymax, as12) <- convType2CExpr (TAp (TAp tMax t1) t2)
  ynp <- mkNEq ymax yt3
  return $ Just (ynp, as3 ++ as12)
genPredInequality p@(IsIn c [t1, t2, t3]) | classId c == idMin = do
  when traceTest $ traceM("pred: " ++ ppReadable p)
  (yt3, as3) <- convType2CExpr t3
  (ymin, as12) <- convType2CExpr (TAp (TAp tMin t1) t2)
  ynp <- mkNEq ymin yt3
  return $ Just (ynp, as3 ++ as12)
genPredInequality p@(IsIn c [t1, t2, t3]) | classId c == idDiv = do
  when traceTest $ traceM("pred: " ++ ppReadable p)
  (yt3, as3) <- convType2CExpr t3
  (ydiv, as12) <- convType2CExpr (TAp (TAp tDiv t1) t2)
  ynp <- mkNEq ydiv yt3
  return $ Just (ynp, as3 ++ as12)
genPredInequality p@(IsIn c [t1, t2, t3]) | classId c == idLog = do
  when traceTest $ traceM("pred: " ++ ppReadable p)
  (yt3, as3) <- convType2CExpr t3
  (ylog, as12) <- convType2CExpr (TAp (TAp tLog t1) t2)
  ynp <- mkNEq ylog yt3
  return $ Just (ynp, as3 ++ as12)
genPredInequality p = do
  when traceTest $ traceM("pred unknown: " ++ ppReadable p)
  return Nothing

-- -------------------------

checkSAT :: CM (Maybe Bool)
checkSAT = do
  ctx <- gets context
  yf <- liftIO $ C.mkFalse ctx
  sat_res <- liftIO $ C.query ctx yf
  -- if query(False) is Valid, then there is an inconsistency,
  -- so the asserted expressions are not satisfiable
  case (sat_res) of
    C.Invalid -> return $ Just True
    C.Valid -> return $ Just False
    C.Timeout -> return Nothing
    C.Error -> internalError ("CVC5 query error")

-- -------------------------

-- Use these functions to make sure that info is added to the most recent maps.
-- If you have a local copy of the map around, but then call monadic functions,
-- the local copy may become stale, and you'll lose info if you write back the
-- stale copy.

addToTypeMap :: Type -> (C.Expr, [C.Expr]) -> CM ()
addToTypeMap t res = do
    s <- get
    let tmap = typeCExprMap s
        tmap' = M.insert t res tmap
    put (s {typeCExprMap = tmap' })

-- -------------------------

getUnknownName :: CM String
getUnknownName = do
    s <- get
    let n = unknownId s
    -- XXX we need to check for name clash
    let str = "__unknown_" ++ itos n
    put (s { unknownId = n + 1})
    return str

mkUnknownVar :: CM C.Expr
mkUnknownVar = do
    ctx <- gets context
    str <- getUnknownName
    ty <- gets intType
    liftIO $ C.mkVar ctx str ty

addUnknownType :: Type -> CM (C.Expr, [C.Expr])
addUnknownType t = do
    when traceConv $ traceM("addUnknownType: " ++ ppString t)
    tmap <- gets typeCExprMap
    case (M.lookup t tmap) of
      Just res -> do when traceConv $ traceM("   reusing.")
                     return res
      Nothing -> do
        when traceConv $ traceM("   making new var.")
        var <- mkUnknownVar
        let res = (var, [])
        addToTypeMap t res
        return res

-- -------------------------

convType2CExpr :: Type -> CM (C.Expr, [C.Expr])
convType2CExpr t = do
  when traceConv $ traceM("converting: " ++ ppReadable t)
  tmap <- gets typeCExprMap
  case (M.lookup t tmap) of
    Just res -> do when traceConv $ traceM("   reusing.")
                   return res
    Nothing -> do
      when traceConv $ traceM("   converting new.")
      yt <- convType2CExpr' t
      addToTypeMap t yt
      return yt

convType2CExpr' :: Type -> CM (C.Expr, [C.Expr])
convType2CExpr' t@(TVar {}) = do
  when traceConv $ traceM("conv TyVar: " ++ ppReadable t)
  addUnknownType t
convType2CExpr' t@(TCon (TyNum n _)) = do
  when traceConv $ traceM("conv TyNum: " ++ ppReadable n)
  ctx <- gets context
  res <- liftIO $ C.mkBVConstantFromInteger ctx intWidth n
  return (res, [])
convType2CExpr' t@(TAp (TAp tc t1) t2) | (tc == tAdd) = do
  when traceConv $ traceM("conv TAdd: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  res <- liftIO $ C.mkBVAdd ctx intWidth yt1 yt2
  -- assert that there is no overflow
  ygte1 <- liftIO $ C.mkBVGe ctx res yt1
  return (res, [ygte1] ++ as1 ++ as2)
convType2CExpr' t@(TAp (TAp tc t1) t2) | (tc == tSub) = do
  when traceConv $ traceM("conv TSub: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  res <- liftIO $ C.mkBVSub ctx intWidth yt1 yt2
  -- assert that there is no underflow
  ygte1 <- liftIO $ C.mkBVGe ctx yt1 res
  return (res, [ygte1] ++ as1 ++ as2)
convType2CExpr' t@(TAp (TAp tc t1) t2) | (tc == tMul) = do
  when traceConv $ traceM("conv TMul: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  res <- liftIO $ C.mkBVMul ctx intWidth yt1 yt2
  -- assert that there is no overflow: (t2 == 0) || (res >= t1)
  yzero <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 0
  yeqz2 <- liftIO $ C.mkEq ctx yt2 yzero
  ygte1 <- liftIO $ C.mkBVGe ctx res yt1
  yor <- liftIO $ C.mkOr ctx yeqz2 ygte1
  return (res, [yor] ++ as1 ++ as2)
convType2CExpr' t@(TAp tc t1) | (tc == tExp) = do
  when traceConv $ traceM("conv TExp: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  yone <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 1
  res <- liftIO $ C.mkBVShiftLeftExpr ctx intWidth yone yt1
  -- assert that there is no overflow: (t1 == 0) || (res >= t1)
  yzero <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 0
  yeqz1 <- liftIO $ C.mkEq ctx yt1 yzero
  ygte1 <- liftIO $ C.mkBVGe ctx res yt1
  yor <- liftIO $ C.mkOr ctx yeqz1 ygte1
  return (res, [yor] ++ as1)
convType2CExpr' t@(TAp (TAp tc t1) t2) | (tc == tMax) = do
  when traceConv $ traceM("conv TMax: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  y_t1gt <- liftIO $ C.mkBVGt ctx yt1 yt2
  res <- liftIO $ C.mkIte ctx y_t1gt yt1 yt2
  return (res, as1 ++ as2)
convType2CExpr' t@(TAp (TAp tc t1) t2) | (tc == tMin) = do
  when traceConv $ traceM("conv TMin: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  y_t1gt <- liftIO $ C.mkBVGt ctx yt1 yt2
  res <- liftIO $ C.mkIte ctx y_t1gt yt2 yt1
  return (res, as1 ++ as2)
convType2CExpr' t@(TAp (TAp tc t1) t2) | (tc == tDiv) = do
  when traceConv $ traceM("conv TDiv: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  -- A division operator exists, but TDiv returns the ceiling, not floor.
  -- So create a variable "v" ...
  var <- mkUnknownVar
  -- and assert that:
  -- (t2 * v <= t1)
  ymul <- liftIO $ C.mkBVMul ctx intWidth yt2 var
  yle <- liftIO $ C.mkBVLe ctx ymul yt1
  -- and (t1 < t2 * (v + 1))
  -- XXX consider using (t2 * v) + t2 for better sharing?
  yone <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 1
  yt2plus1 <- liftIO $ C.mkBVAdd ctx intWidth yt2 yone
  ymul1 <- liftIO $ C.mkBVMul ctx intWidth yt2 yt2plus1
  ylt <- liftIO $ C.mkBVLt ctx yt1 ymul1
  -- assert that t2 is not zero
  -- XXX is this necessary?
  yzero <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 0
  yneqz2 <- mkNEq yt2 yzero
  -- return the variable
  return (var, [yle, ylt, yneqz2] ++ as1 ++ as2)
convType2CExpr' t@(TAp tc t1) | (tc == tLog) = do
  when traceConv $ traceM("conv TLog: " ++ ppReadable t)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  -- Create a variable "v" ...
  var <- mkUnknownVar
  -- and assert that:
  -- ((1 << v) <= t1)
  yone <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 1
  texp <- liftIO $ C.mkBVShiftLeftExpr ctx intWidth yone var
  yle <- liftIO $ C.mkBVLe ctx texp yt1
  -- and (t1 < (1 << (v + 1)))
  -- but expressed as a multiply for better sharing:
  -- (t1 < (2 * (1 << v)))
  ytwo <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 2
  yexp1 <- liftIO $ C.mkBVMul ctx intWidth ytwo texp
  ylt <- liftIO $ C.mkBVLt ctx yt1 yexp1
  -- assert that t1 is not zero
  -- XXX is this necessary?
  yzero <- liftIO $ C.mkBVConstantFromInteger ctx intWidth 0
  yneqz1 <- mkNEq yt1 yzero
  -- return the variable
  return (var, [yle, ylt, yneqz1] ++ as1)
convType2CExpr' t = do
  when traceConv $ traceM("conv unknown: " ++ ppReadable t)
  addUnknownType t

-- -------------------------

assertPred :: Pred -> CM ()
assertPred p@(IsIn c [t1, t2]) | classId c == idNumEq = do
  when traceTest $ traceM("asserting: " ++ ppReadable p)
  ctx <- gets context
  (yt1, as1) <- convType2CExpr t1
  (yt2, as2) <- convType2CExpr t2
  yeq <- liftIO $ C.mkEq ctx yt1 yt2
  mapM_ (liftIO . C.assert ctx) $ [yeq] ++ as1 ++ as2
assertPred p@(IsIn c [t1, t2, t3]) | classId c == idAdd = do
  when traceTest $ traceM("asserting: " ++ ppReadable p)
  ctx <- gets context
  (yt3, as3) <- convType2CExpr t3
  (yadd, as12) <- convType2CExpr (TAp (TAp tAdd t1) t2)
  yeq <- liftIO $ C.mkEq ctx yadd yt3
  mapM_ (liftIO . C.assert ctx) $ [yeq] ++ as3 ++ as12
assertPred p@(IsIn c [t1, t2, t3]) | classId c == idMul = do
  when traceTest $ traceM("asserting: " ++ ppReadable p)
  ctx <- gets context
  (yt3, as3) <- convType2CExpr t3
  (ymul, as12) <- convType2CExpr (TAp (TAp tMul t1) t2)
  yeq <- liftIO $ C.mkEq ctx ymul yt3
  mapM_ (liftIO . C.assert ctx) $ [yeq] ++ as3 ++ as12
assertPred p@(IsIn c [t1, t2, t3]) | classId c == idMax = do
  when traceTest $ traceM("asserting: " ++ ppReadable p)
  ctx <- gets context
  (yt3, as3) <- convType2CExpr t3
  (ymax, as12) <- convType2CExpr (TAp (TAp tMax t1) t2)
  yeq <- liftIO $ C.mkEq ctx ymax yt3
  mapM_ (liftIO . C.assert ctx) $ [yeq] ++ as3 ++ as12
assertPred p@(IsIn c [t1, t2, t3]) | classId c == idMin = do
  when traceTest $ traceM("asserting: " ++ ppReadable p)
  ctx <- gets context
  (yt3, as3) <- convType2CExpr t3
  (ymin, as12) <- convType2CExpr (TAp (TAp tMin t1) t2)
  yeq <- liftIO $ C.mkEq ctx ymin yt3
  mapM_ (liftIO . C.assert ctx) $ [yeq] ++ as3 ++ as12
assertPred p@(IsIn c [t1, t2, t3]) | classId c == idDiv = do
  when traceTest $ traceM("asserting: " ++ ppReadable p)
  ctx <- gets context
  (yt3, as3) <- convType2CExpr t3
  (ydiv, as12) <- convType2CExpr (TAp (TAp tDiv t1) t2)
  yeq <- liftIO $ C.mkEq ctx ydiv yt3
  mapM_ (liftIO . C.assert ctx) $ [yeq] ++ as3 ++ as12
assertPred p@(IsIn c [t1, t2]) | classId c == idLog = do
  when traceTest $ traceM("asserting: " ++ ppReadable p)
  ctx <- gets context
  (yt2, as2) <- convType2CExpr t2
  (ylog, as1) <- convType2CExpr (TAp tLog t1)
  yeq <- liftIO $ C.mkEq ctx ylog yt2
  mapM_ (liftIO . C.assert ctx) $ [yeq] ++ as2 ++ as1
assertPred p = do
  when traceTest $ traceM("ignoring pred: " ++ ppReadable p)
  return ()

-- -------------------------

classId :: Class -> Id
classId = typeclassId . name

-- -------------------------

mkNEq :: C.Expr -> C.Expr -> CM C.Expr
mkNEq y1 y2 = do
  ctx <- gets context
  yeq <- liftIO $ C.mkEq ctx y1 y2
  liftIO $ C.mkNot ctx yeq

-- -------------------------
