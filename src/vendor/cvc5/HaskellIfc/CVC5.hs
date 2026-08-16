{-# LANGUAGE ForeignFunctionInterface   #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Haskell interface to the cvc5 SMT solver, via the @bsc_cvc5@ C shim
-- (see @src\/vendor\/cvc5\/bsc_cvc5.c@).
--
-- This provides the bit-vector/boolean subset of the solver API that BSC
-- needs.  It intentionally has the same shape as the old STP interface,
-- so the conversion modules (AExpr2CVC5, Pred2CVC5) read the same way as
-- their STP predecessors.
module CVC5 (

    -- * Core CVC5 types
    Context,
    Type,
    Expr,
    Result(..),

    -- * Version info
    version,

    -- * Manipulating contexts
    mkContext,
    ctxPush,
    ctxPop,

    -- * Making assertions
    assert,

    -- * Queries
    query,

    -- * CVC5 Types
    mkBoolType,
    mkBitVectorType,

    -- * CVC5 Expressions

    -- ** Type conversion
    mkBoolToBitVector,

    -- ** Variables
    mkVar,

    -- ** Constants
    mkTrue, mkFalse,
    mkBVConstantFromInteger,

    -- ** Logical operators
    mkEq,
    mkNot,
    mkAnd, mkAndMany,
    mkOr, mkOrMany,
    mkXor,
    mkImplies,
    mkIff,
    mkIte,

    -- ** Bit-vector arithmetic
    mkBVAdd, mkBVSub, mkBVMul, mkBVDiv, mkBVMod,
    mkBVSignedDiv, mkBVSignedMod,
    mkBVMinus,

    -- ** Bit-vector comparisons
    mkBVLt, mkBVLe,
    mkBVGt, mkBVGe,

    mkBVSlt, mkBVSle,
    mkBVSgt, mkBVSge,

    -- ** Bitwise operations
    mkBVAnd, mkBVOr, mkBVXor,
    mkBVNot,

    -- ** Bit-vector shifting and signs
    mkBVSignExtend,
    mkBVShiftLeft, mkBVShiftRight,
    mkBVShiftLeftExpr, mkBVShiftRightExpr, mkBVSignedShiftRightExpr,

    -- ** Bit-vector strings
    mkBVConcat,
    mkBVExtract, mkBVBoolExtract

    ) where

import CVC5FFI

import Foreign
import Foreign.C.String
import qualified Foreign.Concurrent as F

import Control.Monad (when)
import Control.Concurrent.MVar.Strict

import ErrorUtil(internalError)

------------------------------------------------------------------------
-- Types

-- | A cvc5 /context/
--
-- A context owns a cvc5 solver (and its term manager).
--
-- /Notes:/
--
-- * The resource is automatically managed by the Haskell garbage
-- collector, and the solver is automatically deleted once it is out
-- of scope (no need to call 'bsc_cvc5_delete'.)
--
-- * The terms created from a context are only valid while the context
-- is alive.  This is guaranteed because the context is always part of
-- the state that carries the terms.
--
-- * Improving on the raw API, we maintain a stack depth, to prevent
-- errors relating to uneven numbers of 'push' and 'pop' operations.
-- 'pop' on a zero depth stack leaves the stack at zero.
--
data Context = Context { sContext :: ForeignPtr CCvc5Context
                       , sDepth   :: !(MVar Integer)
                       }
    deriving Eq

-- | cvc5 sorts
--
newtype Type = Type { unType :: Ptr CCvc5Sort }
    deriving (Eq, Ord, Show, Storable)

-- | cvc5 /expressions/ (terms)
--
newtype Expr = Expr { unExpr :: Ptr CCvc5Term }
    deriving (Eq, Ord, Show, Storable)

-- The return type for queries
--
-- (This mirrors the result type of the old STP binding, which the
-- conversion modules pattern-match on.)
data Result
    = Invalid
    | Valid
    | Error
    | Timeout
    deriving (Eq, Ord, Enum, Bounded, Read, Show)

toResult :: Word8 -> Result
toResult n
    | n == 0 = Invalid
    | n == 1 = Valid
    | n == 2 = Error
    | n == 3 = Timeout
    | otherwise = internalError("CVC5.toResult: " ++ show n)

------------------------------------------------------------------------

-- | The version string of the underlying cvc5 library
--
version :: Context -> IO String
version c = withForeignPtr (sContext c) $ \cptr ->
    peekCString =<< bsc_cvc5_get_version cptr

------------------------------------------------------------------------
-- Context manipulation

-- | Create a new logical context (a cvc5 solver instance).
-- When the context goes out of scope, it will be automatically deleted.
--
mkContext :: IO Context
mkContext = do
    ptr <- bsc_cvc5_new
    when (ptr == nullPtr) $
        internalError ("CVC5.mkContext: failed to create a solver context")
    fp  <- F.newForeignPtr ptr (bsc_cvc5_delete ptr)
    n   <- newMVar 0
    return $! Context fp n

-- | Create a backtracking point in the given logical context.
--
ctxPush :: Context -> IO ()
ctxPush c = modifyMVar_ (sDepth c) $ \n ->
    if n < 0
        then error "CVC5.ctxPush: Corrupted Context. Stack depth < 0"
        else do
            withForeignPtr (sContext c) $ bsc_cvc5_push
            return (n+1)

-- | Backtrack.
--
-- Restores the context from the top of the stack, and pops it off the
-- stack. Any changes to the logical context (by 'assert' or other
-- functions) between the matching 'push' and 'pop' operators are
-- flushed, and the context is completely restored to what it was right
-- before the 'push'.
--
ctxPop :: Context -> IO ()
ctxPop c = modifyMVar_ (sDepth c) $ \n -> case () of
    _ | n <  0    -> error "CVC5.ctxPop: Corrupted context. Stack depth < 0"
      | n == 0    -> return n
      | otherwise -> do
            withForeignPtr (sContext c) $ bsc_cvc5_pop
            return (n-1)

------------------------------------------------------------------------
-- Assertions

-- | Assert a constraint in the logical context.
--
assert :: Context -> Expr -> IO ()
assert c e = withForeignPtr (sContext c) $ \cptr ->
    bsc_cvc5_assert cptr (unExpr e)

------------------------------------------------------------------------
-- Queries

-- | Check if an expression is valid given the logical context.
--
-- * @Invalid@ means the expression is not valid in the context
--   (there exists a counterexample).
--
-- * @Valid@   means the expression is valid in the context.
--
-- * @Error@ means that an error was encountered.
--
-- * @Timeout@ means it was not possible to decide in the given time.
--
query :: Context -> Expr -> IO Result
query c e = toResult <$>
    withForeignPtr (sContext c) (\cptr -> bsc_cvc5_query cptr (unExpr e))

------------------------------------------------------------------------
-- Types

-- | Return the sort for booleans.
--
mkBoolType :: Context -> IO Type
mkBoolType c =
    withForeignPtr (sContext c) $ \cptr ->
        Type <$> bsc_cvc5_mk_bool_sort cptr

-- | Returns a bitvector sort of @n@ size.
--
-- Size must be greater than @0@.
--
mkBitVectorType :: Context -> Int -> IO Type
mkBitVectorType _ n | (n < 1) =
    internalError ("CVC5.mkBitVectorType: " ++ show n)
mkBitVectorType c n =
    withForeignPtr (sContext c) $ \cptr ->
        Type <$> bsc_cvc5_mk_bv_sort cptr (fromIntegral n)

------------------------------------------------------------------------
-- Type conversion

-- | Convert a Boolean expression to a 1-bit bit-vector expression
--
mkBoolToBitVector :: Context -> Expr -> IO Expr
mkBoolToBitVector c e =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bool_to_bv cptr (unExpr e)

------------------------------------------------------------------------
-- Variables

mkVar :: Context -> String -> Type -> IO Expr
mkVar c str t =
    withCString str $ \cstr ->
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_var cptr cstr (unType t)

------------------------------------------------------------------------
-- Constants

-- | Return an expression representing 'True'.
--
mkTrue :: Context -> IO Expr
mkTrue c = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_true cptr

-- | Return an expression representing 'False'.
--
mkFalse :: Context -> IO Expr
mkFalse c = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_false cptr

-- | Create a bit vector constant of size bits and of the given value.
--
-- The value is taken modulo 2^size (so negative values are represented
-- in two's complement).
--
-- @size@ must be positive
--
mkBVConstantFromInteger :: Context -> Integer -> Integer -> IO Expr
mkBVConstantFromInteger _ width _ | (width < 1) =
    internalError ("CVC5.mkBVConstantFromInteger: " ++ show width)
mkBVConstantFromInteger c width val
    | width <= 64 =
        withForeignPtr (sContext c) $ \cptr ->
            Expr <$> bsc_cvc5_mk_bv_const_uint64 cptr
                         (fromInteger width) (fromInteger mval)
    | otherwise =
        withForeignPtr (sContext c) $ \cptr ->
        withCString (show mval) $ \cstr ->
            Expr <$> bsc_cvc5_mk_bv_const_dec_str cptr (fromInteger width) cstr
  where mval = val `mod` (1 `shiftL` (fromInteger width))

------------------------------------------------------------------------
-- Logical operations

-- | Return an expression representing:
--
-- > a1 == a2
--
mkEq :: Context -> Expr -> Expr -> IO Expr
mkEq c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_eq cptr (unExpr e1) (unExpr e2)

-- |    Return an expression representing:
--
-- > not a
--
mkNot :: Context -> Expr -> IO Expr
mkNot c e = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_not cptr (unExpr e)

-- | Return an expression representing the binary /AND/ of the given arguments.
--
mkAnd :: Context -> Expr -> Expr -> IO Expr
mkAnd c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_and cptr (unExpr e1) (unExpr e2)

-- | Return an expression representing the /n/-ary /AND/ of the given arguments.
--
-- > and [a1, ..]
--
mkAndMany :: Context -> [Expr] -> IO Expr
mkAndMany _ [] = error "CVC5.mkAndMany: empty list of expressions"
mkAndMany c es =
    withArray (map unExpr es) $ \aptr ->
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_and_n cptr (fromIntegral (length es)) aptr

-- | Return an expression representing the binary /OR/ of the given arguments.
--
mkOr :: Context -> Expr -> Expr -> IO Expr
mkOr c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_or cptr (unExpr e1) (unExpr e2)

-- | Return an expression representing the /n/-ary /OR/ of the given arguments.
--
-- > or [a1, ..]
--
mkOrMany :: Context -> [Expr] -> IO Expr
mkOrMany _ [] = error "CVC5.mkOrMany: empty list of expressions"
mkOrMany c es =
    withArray (map unExpr es) $ \aptr ->
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_or_n cptr (fromIntegral (length es)) aptr

-- | Return an expression representing the binary /XOR/ of the given arguments.
--
mkXor :: Context -> Expr -> Expr -> IO Expr
mkXor c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_xor cptr (unExpr e1) (unExpr e2)

-- | Return an expression representing:
--
-- > e1 implies e2
--
mkImplies :: Context -> Expr -> Expr -> IO Expr
mkImplies c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_implies cptr (unExpr e1) (unExpr e2)

-- | Return an expression representing:
--
-- > e1 if-and-only-if e2
--
mkIff :: Context -> Expr -> Expr -> IO Expr
mkIff c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_iff cptr (unExpr e1) (unExpr e2)

-- | Return an expression representing:
--
-- > if b then e1 else e2
--
mkIte :: Context -> Expr -> Expr -> Expr -> IO Expr
mkIte c b e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_ite cptr (unExpr b) (unExpr e1) (unExpr e2)

------------------------------------------------------------------------
-- Bit-vector arithmetic

-- Note: unlike the STP API, cvc5 infers the width from the operands,
-- so the @Int@ size arguments of these functions are ignored (they are
-- kept so that this interface matches the old one).

-- | Bitvector addition.
--
-- @a1@ and @a2@ must be bitvector expressions of same size.
--
mkBVAdd :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVAdd c _ e1 e2 =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bv_add cptr (unExpr e1) (unExpr e2)

-- | Bitvector subtraction.
--
-- @a1@ and @a2@ must be bitvector expressions of same size.
--
mkBVSub :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVSub c _ e1 e2 =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bv_sub cptr (unExpr e1) (unExpr e2)

-- | Bitvector multiplication.
--
-- @a1@ and @a2@ must be bitvector expressions of same size.
-- (The result is truncated to that size?)
--
mkBVMul :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVMul c _ e1 e2 =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bv_mul cptr (unExpr e1) (unExpr e2)

-- | Bitvector division (unsigned)
--
-- @a1@ and @a2@ must be bitvector expressions of same size.
-- Division by zero is total (it returns all-ones, per SMT-LIB).
--
mkBVDiv :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVDiv c _ e1 e2 =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bv_udiv cptr (unExpr e1) (unExpr e2)

-- | Bitvector mod (unsigned remainder)
--
-- @a1@ and @a2@ must be bitvector expressions of same size.
--
mkBVMod :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVMod c _ e1 e2 =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bv_urem cptr (unExpr e1) (unExpr e2)

-- | Bitvector division (signed)
--
-- @a1@ and @a2@ must be bitvector expressions of same size.
--
mkBVSignedDiv :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVSignedDiv c _ e1 e2 =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bv_sdiv cptr (unExpr e1) (unExpr e2)

-- | Bitvector mod (signed)
--
-- @a1@ and @a2@ must be bitvector expressions of same size.
--
mkBVSignedMod :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVSignedMod c _ e1 e2 =
    withForeignPtr (sContext c) $ \cptr ->
        Expr <$> bsc_cvc5_mk_bv_smod cptr (unExpr e1) (unExpr e2)

-- | Bitvector uniary minus.
--
-- @a1@ must be bitvector expression. The result is @(- a1)@.
--
mkBVMinus :: Context -> Expr -> IO Expr
mkBVMinus c e = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_neg cptr (unExpr e)

------------------------------------------------------------------------
-- Bit-vector comparisons

-- | Unsigned bitvector comparison:
--
-- > a1 < a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVLt :: Context -> Expr -> Expr -> IO Expr
mkBVLt c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_ult cptr (unExpr e1) (unExpr e2)

-- | Unsigned bitvector comparison:
--
-- > a1 <= a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVLe :: Context -> Expr -> Expr -> IO Expr
mkBVLe c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_ule cptr (unExpr e1) (unExpr e2)

-- | Unsigned bitvector comparison:
--
-- > a1 > a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVGt :: Context -> Expr -> Expr -> IO Expr
mkBVGt c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_ugt cptr (unExpr e1) (unExpr e2)

-- | Unsigned bitvector comparison:
--
-- > a1 >= a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVGe :: Context -> Expr -> Expr -> IO Expr
mkBVGe c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_uge cptr (unExpr e1) (unExpr e2)

-- | Signed bitvector comparison:
--
-- > a1 < a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVSlt :: Context -> Expr -> Expr -> IO Expr
mkBVSlt c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_slt cptr (unExpr e1) (unExpr e2)

-- | Signed bitvector comparison:
--
-- > a1 <= a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVSle :: Context -> Expr -> Expr -> IO Expr
mkBVSle c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_sle cptr (unExpr e1) (unExpr e2)

-- | Signed bitvector comparison:
--
-- > a1 > a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVSgt :: Context -> Expr -> Expr -> IO Expr
mkBVSgt c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_sgt cptr (unExpr e1) (unExpr e2)

-- | Signed bitvector comparison:
--
-- > a1 >= a2
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVSge :: Context -> Expr -> Expr -> IO Expr
mkBVSge c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_sge cptr (unExpr e1) (unExpr e2)

------------------------------------------------------------------------
-- Bit-wise operations

-- | Bitwise @and@.
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVAnd :: Context -> Expr -> Expr -> IO Expr
mkBVAnd c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_and cptr (unExpr e1) (unExpr e2)

-- | Bitwise @or@.
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVOr :: Context -> Expr -> Expr -> IO Expr
mkBVOr c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_or cptr (unExpr e1) (unExpr e2)

-- | Bitwise @xor@.
--
-- /a1/ and /a2/ must be bitvector expressions of same size.
--
mkBVXor :: Context -> Expr -> Expr -> IO Expr
mkBVXor c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_xor cptr (unExpr e1) (unExpr e2)

-- | Bitwise negation.
--
mkBVNot :: Context -> Expr -> IO Expr
mkBVNot c e = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_not cptr (unExpr e)

------------------------------------------------------------------------
-- Bit-vector shifting and signs

-- | Sign extension.
--
-- Extend (or truncate) /a/ so that the result is /n/ bits wide,
-- preserving the sign.  (This matches the semantics of the old STP
-- interface, where /n/ is the total resulting width.)
--
mkBVSignExtend :: Context -> Expr -> Int -> IO Expr
mkBVSignExtend c e n = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_sign_extend_to cptr (unExpr e) (fromIntegral n)

-- | Left shift by n bits, padding with zeros.
--
mkBVShiftLeft :: Context -> Expr -> Int -> IO Expr
mkBVShiftLeft c e n = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_shl_const cptr (unExpr e) (fromIntegral n)


-- | Right shift by n bits, padding with zeros.
--
mkBVShiftRight :: Context -> Expr -> Int -> IO Expr
mkBVShiftRight c e n = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_lshr_const cptr (unExpr e) (fromIntegral n)

-- | Dynamic shift operations.
--
-- Note that (unlike STP) cvc5 requires the two operands to have the
-- same width; the callers already extend the arguments to a common
-- size before calling these.
mkBVShiftLeftExpr :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVShiftLeftExpr c _ e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_shl cptr (unExpr e1) (unExpr e2)

mkBVShiftRightExpr :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVShiftRightExpr c _ e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_lshr cptr (unExpr e1) (unExpr e2)

mkBVSignedShiftRightExpr :: Context -> Int -> Expr -> Expr -> IO Expr
mkBVSignedShiftRightExpr c _ e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_ashr cptr (unExpr e1) (unExpr e2)

------------------------------------------------------------------------
-- Bit vector strings

-- | Bitvector concatenation.
--
-- @a1@ and @a2@ must be two bitvector expressions.
-- @a1@ is the left part of the result and @a2@ the right part.
--
-- Assuming /a1/ and /a2/ have /n1/ and /n2/ bits, respectively, then the
-- result is a bitvector concat of size /n1 + n2/. Bit 0 of concat is bit 0 of
-- /a2/ and bit n2 of concat is bit 0 of /a1/.
--
mkBVConcat :: Context -> Expr -> Expr -> IO Expr
mkBVConcat c e1 e2 = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_concat cptr (unExpr e1) (unExpr e2)

-- | Bitvector extraction.
--
-- The first @Int@ argument is the initial index, the second is the end index.
-- /Note/: this is reversed wrt. the underlying API.
--
-- /a/ must a bitvector expression of size /n/ with @begin <= end < n@.
-- The result is the subvector slice @a[end .. begin]@.
--
mkBVExtract :: Context -> Int -> Int -> Expr -> IO Expr
mkBVExtract c begin end e = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_extract cptr (unExpr e)
                 (fromIntegral end) (fromIntegral begin)

-- | Bitvector extraction to Boolean result
--
-- > x[bit_no:bit_no] == 1
--
mkBVBoolExtract :: Context -> Int -> Expr -> IO Expr
mkBVBoolExtract c idx e = withForeignPtr (sContext c) $ \cptr ->
    Expr <$> bsc_cvc5_mk_bv_bool_extract_one cptr (unExpr e) (fromIntegral idx)

------------------------------------------------------------------------
