{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE EmptyDataDecls           #-}

-- | Raw FFI imports of the @bsc_cvc5@ C shim over the cvc5 C API.
-- See @src\/vendor\/cvc5\/bsc_cvc5.c@.
module CVC5FFI (

    -- * C types
    CCvc5Context,
    CCvc5Sort,
    CCvc5Term,

    -- * Context manipulation
    bsc_cvc5_new,
    bsc_cvc5_delete,
    bsc_cvc5_get_version,
    bsc_cvc5_push,
    bsc_cvc5_pop,
    bsc_cvc5_assert,
    bsc_cvc5_query,

    -- * Sorts
    bsc_cvc5_mk_bool_sort,
    bsc_cvc5_mk_bv_sort,

    -- * Variables and constants
    bsc_cvc5_mk_var,
    bsc_cvc5_mk_true,
    bsc_cvc5_mk_false,
    bsc_cvc5_mk_bv_const_uint64,
    bsc_cvc5_mk_bv_const_dec_str,

    -- * Logical operators
    bsc_cvc5_mk_not,
    bsc_cvc5_mk_and,
    bsc_cvc5_mk_or,
    bsc_cvc5_mk_xor,
    bsc_cvc5_mk_and_n,
    bsc_cvc5_mk_or_n,
    bsc_cvc5_mk_implies,
    bsc_cvc5_mk_iff,
    bsc_cvc5_mk_eq,
    bsc_cvc5_mk_ite,
    bsc_cvc5_mk_bool_to_bv,

    -- * Bit-vector arithmetic
    bsc_cvc5_mk_bv_add,
    bsc_cvc5_mk_bv_sub,
    bsc_cvc5_mk_bv_mul,
    bsc_cvc5_mk_bv_udiv,
    bsc_cvc5_mk_bv_urem,
    bsc_cvc5_mk_bv_sdiv,
    bsc_cvc5_mk_bv_srem,
    bsc_cvc5_mk_bv_smod,
    bsc_cvc5_mk_bv_neg,

    -- * Bit-vector comparisons
    bsc_cvc5_mk_bv_ult,
    bsc_cvc5_mk_bv_ule,
    bsc_cvc5_mk_bv_ugt,
    bsc_cvc5_mk_bv_uge,
    bsc_cvc5_mk_bv_slt,
    bsc_cvc5_mk_bv_sle,
    bsc_cvc5_mk_bv_sgt,
    bsc_cvc5_mk_bv_sge,

    -- * Bitwise operations
    bsc_cvc5_mk_bv_and,
    bsc_cvc5_mk_bv_or,
    bsc_cvc5_mk_bv_xor,
    bsc_cvc5_mk_bv_not,

    -- * Shifts
    bsc_cvc5_mk_bv_shl,
    bsc_cvc5_mk_bv_lshr,
    bsc_cvc5_mk_bv_ashr,
    bsc_cvc5_mk_bv_shl_const,
    bsc_cvc5_mk_bv_lshr_const,

    -- * Concatenation, extraction and extension
    bsc_cvc5_mk_bv_concat,
    bsc_cvc5_mk_bv_extract,
    bsc_cvc5_mk_bv_sign_extend_to,
    bsc_cvc5_mk_bv_bool_extract_one,

    ) where

import Foreign
import Foreign.C.String

------------------------------------------------------------------------
-- C types

-- | The shim context (owns a cvc5 term manager and solver)
data CCvc5Context

-- | A cvc5 sort
data CCvc5Sort

-- | A cvc5 term
data CCvc5Term

------------------------------------------------------------------------
-- Context manipulation

foreign import ccall unsafe "bsc_cvc5_new"
    bsc_cvc5_new :: IO (Ptr CCvc5Context)

foreign import ccall unsafe "bsc_cvc5_delete"
    bsc_cvc5_delete :: Ptr CCvc5Context -> IO ()

foreign import ccall unsafe "bsc_cvc5_get_version"
    bsc_cvc5_get_version :: Ptr CCvc5Context -> IO CString

foreign import ccall unsafe "bsc_cvc5_push"
    bsc_cvc5_push :: Ptr CCvc5Context -> IO ()

foreign import ccall unsafe "bsc_cvc5_pop"
    bsc_cvc5_pop :: Ptr CCvc5Context -> IO ()

foreign import ccall unsafe "bsc_cvc5_assert"
    bsc_cvc5_assert :: Ptr CCvc5Context -> Ptr CCvc5Term -> IO ()

foreign import ccall unsafe "bsc_cvc5_query"
    bsc_cvc5_query :: Ptr CCvc5Context -> Ptr CCvc5Term -> IO Word8

------------------------------------------------------------------------
-- Sorts

foreign import ccall unsafe "bsc_cvc5_mk_bool_sort"
    bsc_cvc5_mk_bool_sort :: Ptr CCvc5Context -> IO (Ptr CCvc5Sort)

foreign import ccall unsafe "bsc_cvc5_mk_bv_sort"
    bsc_cvc5_mk_bv_sort :: Ptr CCvc5Context -> Word32 -> IO (Ptr CCvc5Sort)

------------------------------------------------------------------------
-- Variables and constants

foreign import ccall unsafe "bsc_cvc5_mk_var"
    bsc_cvc5_mk_var :: Ptr CCvc5Context -> CString -> Ptr CCvc5Sort
                    -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_true"
    bsc_cvc5_mk_true :: Ptr CCvc5Context -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_false"
    bsc_cvc5_mk_false :: Ptr CCvc5Context -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_const_uint64"
    bsc_cvc5_mk_bv_const_uint64 :: Ptr CCvc5Context -> Word32 -> Word64
                                -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_const_dec_str"
    bsc_cvc5_mk_bv_const_dec_str :: Ptr CCvc5Context -> Word32 -> CString
                                 -> IO (Ptr CCvc5Term)

------------------------------------------------------------------------
-- Logical operators

foreign import ccall unsafe "bsc_cvc5_mk_not"
    bsc_cvc5_mk_not :: Ptr CCvc5Context -> Ptr CCvc5Term -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_and"
    bsc_cvc5_mk_and :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                    -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_or"
    bsc_cvc5_mk_or :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                   -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_xor"
    bsc_cvc5_mk_xor :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                    -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_and_n"
    bsc_cvc5_mk_and_n :: Ptr CCvc5Context -> Word32 -> Ptr (Ptr CCvc5Term)
                      -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_or_n"
    bsc_cvc5_mk_or_n :: Ptr CCvc5Context -> Word32 -> Ptr (Ptr CCvc5Term)
                     -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_implies"
    bsc_cvc5_mk_implies :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_iff"
    bsc_cvc5_mk_iff :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                    -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_eq"
    bsc_cvc5_mk_eq :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                   -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_ite"
    bsc_cvc5_mk_ite :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                    -> Ptr CCvc5Term -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bool_to_bv"
    bsc_cvc5_mk_bool_to_bv :: Ptr CCvc5Context -> Ptr CCvc5Term
                           -> IO (Ptr CCvc5Term)

------------------------------------------------------------------------
-- Bit-vector arithmetic

foreign import ccall unsafe "bsc_cvc5_mk_bv_add"
    bsc_cvc5_mk_bv_add :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_sub"
    bsc_cvc5_mk_bv_sub :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_mul"
    bsc_cvc5_mk_bv_mul :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_udiv"
    bsc_cvc5_mk_bv_udiv :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_urem"
    bsc_cvc5_mk_bv_urem :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_sdiv"
    bsc_cvc5_mk_bv_sdiv :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_srem"
    bsc_cvc5_mk_bv_srem :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_smod"
    bsc_cvc5_mk_bv_smod :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_neg"
    bsc_cvc5_mk_bv_neg :: Ptr CCvc5Context -> Ptr CCvc5Term -> IO (Ptr CCvc5Term)

------------------------------------------------------------------------
-- Bit-vector comparisons

foreign import ccall unsafe "bsc_cvc5_mk_bv_ult"
    bsc_cvc5_mk_bv_ult :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_ule"
    bsc_cvc5_mk_bv_ule :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_ugt"
    bsc_cvc5_mk_bv_ugt :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_uge"
    bsc_cvc5_mk_bv_uge :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_slt"
    bsc_cvc5_mk_bv_slt :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_sle"
    bsc_cvc5_mk_bv_sle :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_sgt"
    bsc_cvc5_mk_bv_sgt :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_sge"
    bsc_cvc5_mk_bv_sge :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

------------------------------------------------------------------------
-- Bitwise operations

foreign import ccall unsafe "bsc_cvc5_mk_bv_and"
    bsc_cvc5_mk_bv_and :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_or"
    bsc_cvc5_mk_bv_or :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_xor"
    bsc_cvc5_mk_bv_xor :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_not"
    bsc_cvc5_mk_bv_not :: Ptr CCvc5Context -> Ptr CCvc5Term -> IO (Ptr CCvc5Term)

------------------------------------------------------------------------
-- Shifts

foreign import ccall unsafe "bsc_cvc5_mk_bv_shl"
    bsc_cvc5_mk_bv_shl :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                       -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_lshr"
    bsc_cvc5_mk_bv_lshr :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_ashr"
    bsc_cvc5_mk_bv_ashr :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                        -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_shl_const"
    bsc_cvc5_mk_bv_shl_const :: Ptr CCvc5Context -> Ptr CCvc5Term -> Word32
                             -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_lshr_const"
    bsc_cvc5_mk_bv_lshr_const :: Ptr CCvc5Context -> Ptr CCvc5Term -> Word32
                              -> IO (Ptr CCvc5Term)

------------------------------------------------------------------------
-- Concatenation, extraction and extension

foreign import ccall unsafe "bsc_cvc5_mk_bv_concat"
    bsc_cvc5_mk_bv_concat :: Ptr CCvc5Context -> Ptr CCvc5Term -> Ptr CCvc5Term
                          -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_extract"
    bsc_cvc5_mk_bv_extract :: Ptr CCvc5Context -> Ptr CCvc5Term
                           -> Word32 -> Word32 -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_sign_extend_to"
    bsc_cvc5_mk_bv_sign_extend_to :: Ptr CCvc5Context -> Ptr CCvc5Term -> Word32
                                  -> IO (Ptr CCvc5Term)

foreign import ccall unsafe "bsc_cvc5_mk_bv_bool_extract_one"
    bsc_cvc5_mk_bv_bool_extract_one :: Ptr CCvc5Context -> Ptr CCvc5Term
                                    -> Word32 -> IO (Ptr CCvc5Term)

------------------------------------------------------------------------
