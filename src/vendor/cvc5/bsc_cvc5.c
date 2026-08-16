/*
 * Thin C shim over the cvc5 C API, providing the small bit-vector/boolean
 * SMT interface that BSC needs (a replacement for the old STP/Yices
 * interfaces).
 *
 * Wrapping the API in C (rather than importing cvc5 functions directly
 * into Haskell) means that the Cvc5Kind enum values are resolved by the
 * C compiler against the installed <cvc5/c/cvc5.h>, so the Haskell FFI
 * layer only deals with plain pointers and integers.
 *
 * Memory management: cvc5 terms and sorts are owned by the term manager;
 * they stay alive until the term manager is deleted (per-term release is
 * optional in the cvc5 C API), so we only free the solver and the term
 * manager when a context is destroyed.
 */

#include <stdint.h>
#include <stdlib.h>

#include <cvc5/c/cvc5.h>

#include "bsc_cvc5.h"

struct BscCvc5Context {
  Cvc5TermManager* tm;
  Cvc5* slv;
};

BscCvc5Context* bsc_cvc5_new(void) {
  BscCvc5Context* ctx = malloc(sizeof(BscCvc5Context));
  if (ctx == NULL) return NULL;
  ctx->tm = cvc5_term_manager_new();
  ctx->slv = cvc5_new(ctx->tm);
  return ctx;
}

void bsc_cvc5_delete(BscCvc5Context* ctx) {
  if (ctx == NULL) return;
  cvc5_delete(ctx->slv);
  cvc5_term_manager_delete(ctx->tm);
  free(ctx);
}

/* Note: the returned pointer is only valid until the next call to this
   function; the Haskell side copies it immediately with peekCString. */
const char* bsc_cvc5_get_version(BscCvc5Context* ctx) {
  return cvc5_get_version(ctx->slv);
}

void bsc_cvc5_push(BscCvc5Context* ctx) {
  cvc5_push(ctx->slv, 1);
}

void bsc_cvc5_pop(BscCvc5Context* ctx) {
  cvc5_pop(ctx->slv, 1);
}

void bsc_cvc5_assert(BscCvc5Context* ctx, Cvc5Term e) {
  cvc5_assert_formula(ctx->slv, e);
}

/* Query the validity of e: asserts (not e) and checks satisfiability.
   Returns 0 if e is invalid (the context is satisfiable with (not e)),
           1 if e is valid   (the context is unsatisfiable with (not e)),
           3 if the result is unknown.
   (These match the codes that BSC's old STP binding used:
   0=Invalid, 1=Valid, 2=Error, 3=Timeout.) */
uint8_t bsc_cvc5_query(BscCvc5Context* ctx, Cvc5Term e) {
  uint8_t res;
  cvc5_push(ctx->slv, 1);
  Cvc5Term not_e = cvc5_mk_term(ctx->tm, CVC5_KIND_NOT, 1, &e);
  cvc5_assert_formula(ctx->slv, not_e);
  Cvc5Result r = cvc5_check_sat(ctx->slv);
  if (cvc5_result_is_unsat(r)) {
    res = 1;
  } else if (cvc5_result_is_sat(r)) {
    res = 0;
  } else {
    res = 3;
  }
  cvc5_pop(ctx->slv, 1);
  return res;
}

/* ------------------------------------------------------------------ */
/* Sorts                                                                */

Cvc5Sort bsc_cvc5_mk_bool_sort(BscCvc5Context* ctx) {
  return cvc5_get_boolean_sort(ctx->tm);
}

Cvc5Sort bsc_cvc5_mk_bv_sort(BscCvc5Context* ctx, uint32_t width) {
  return cvc5_mk_bv_sort(ctx->tm, width);
}

/* ------------------------------------------------------------------ */
/* Variables and constants                                              */

Cvc5Term bsc_cvc5_mk_var(BscCvc5Context* ctx, const char* name, Cvc5Sort sort) {
  /* NB: cvc5_mk_const (a fresh uninterpreted constant), not cvc5_mk_var
     (a bound variable, for use inside binders only): the solver rejects
     asserted terms that contain free bound-style variables.  Each call
     returns a fresh constant, so duplicate names are harmless. */
  return cvc5_mk_const(ctx->tm, sort, name);
}

Cvc5Term bsc_cvc5_mk_true(BscCvc5Context* ctx) {
  return cvc5_mk_true(ctx->tm);
}

Cvc5Term bsc_cvc5_mk_false(BscCvc5Context* ctx) {
  return cvc5_mk_false(ctx->tm);
}

/* The caller must have masked the value to fit in "width" bits. */
Cvc5Term bsc_cvc5_mk_bv_const_uint64(BscCvc5Context* ctx,
                                     uint32_t width,
                                     uint64_t val) {
  return cvc5_mk_bv_uint64(ctx->tm, width, val);
}

/* The caller must have masked the value to fit in "width" bits.
   "dec" is the decimal string representation of the (unsigned) value. */
Cvc5Term bsc_cvc5_mk_bv_const_dec_str(BscCvc5Context* ctx,
                                      uint32_t width,
                                      const char* dec) {
  return cvc5_mk_bv(ctx->tm, width, dec, 10);
}

/* ------------------------------------------------------------------ */
/* Logical operations                                                   */

static Cvc5Term mk_unop(BscCvc5Context* ctx, Cvc5Kind kind, Cvc5Term a) {
  Cvc5Term children[1] = {a};
  return cvc5_mk_term(ctx->tm, kind, 1, children);
}

static Cvc5Term mk_binop(BscCvc5Context* ctx, Cvc5Kind kind,
                         Cvc5Term a, Cvc5Term b) {
  Cvc5Term children[2] = {a, b};
  return cvc5_mk_term(ctx->tm, kind, 2, children);
}

Cvc5Term bsc_cvc5_mk_not(BscCvc5Context* ctx, Cvc5Term a) {
  return mk_unop(ctx, CVC5_KIND_NOT, a);
}

Cvc5Term bsc_cvc5_mk_and(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_AND, a, b);
}

Cvc5Term bsc_cvc5_mk_or(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_OR, a, b);
}

Cvc5Term bsc_cvc5_mk_xor(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_XOR, a, b);
}

Cvc5Term bsc_cvc5_mk_and_n(BscCvc5Context* ctx,
                           uint32_t n, const Cvc5Term args[]) {
  return cvc5_mk_term(ctx->tm, CVC5_KIND_AND, n, args);
}

Cvc5Term bsc_cvc5_mk_or_n(BscCvc5Context* ctx,
                          uint32_t n, const Cvc5Term args[]) {
  return cvc5_mk_term(ctx->tm, CVC5_KIND_OR, n, args);
}

Cvc5Term bsc_cvc5_mk_implies(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_IMPLIES, a, b);
}

Cvc5Term bsc_cvc5_mk_iff(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_EQUAL, a, b);
}

Cvc5Term bsc_cvc5_mk_eq(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_EQUAL, a, b);
}

Cvc5Term bsc_cvc5_mk_ite(BscCvc5Context* ctx,
                         Cvc5Term c, Cvc5Term t, Cvc5Term f) {
  Cvc5Term children[3] = {c, t, f};
  return cvc5_mk_term(ctx->tm, CVC5_KIND_ITE, 3, children);
}

/* Convert a Bool to a 1-bit bit-vector: (ite b #b1 #b0) */
Cvc5Term bsc_cvc5_mk_bool_to_bv(BscCvc5Context* ctx, Cvc5Term b) {
  Cvc5Term one = cvc5_mk_bv_uint64(ctx->tm, 1, 1);
  Cvc5Term zero = cvc5_mk_bv_uint64(ctx->tm, 1, 0);
  return bsc_cvc5_mk_ite(ctx, b, one, zero);
}

/* ------------------------------------------------------------------ */
/* Bit-vector arithmetic (operands must have matching widths)           */

Cvc5Term bsc_cvc5_mk_bv_add(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_ADD, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_sub(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SUB, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_mul(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_MULT, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_udiv(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_UDIV, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_urem(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_UREM, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_sdiv(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SDIV, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_srem(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SREM, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_smod(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SMOD, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_neg(BscCvc5Context* ctx, Cvc5Term a) {
  return mk_unop(ctx, CVC5_KIND_BITVECTOR_NEG, a);
}

/* ------------------------------------------------------------------ */
/* Bit-vector comparisons (unsigned and signed)                         */

Cvc5Term bsc_cvc5_mk_bv_ult(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_ULT, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_ule(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_ULE, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_ugt(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_UGT, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_uge(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_UGE, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_slt(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SLT, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_sle(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SLE, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_sgt(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SGT, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_sge(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SGE, a, b);
}

/* ------------------------------------------------------------------ */
/* Bitwise operations                                                   */

Cvc5Term bsc_cvc5_mk_bv_and(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_AND, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_or(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_OR, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_xor(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_XOR, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_not(BscCvc5Context* ctx, Cvc5Term a) {
  return mk_unop(ctx, CVC5_KIND_BITVECTOR_NOT, a);
}

/* ------------------------------------------------------------------ */
/* Shifts                                                               */

/* In cvc5 (as in SMT-LIB) both shift operands must have the same width;
   the shift amount is itself a bit-vector. */

Cvc5Term bsc_cvc5_mk_bv_shl(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_SHL, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_lshr(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_LSHR, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_ashr(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_ASHR, a, b);
}

static uint32_t bv_size(Cvc5Term t) {
  return cvc5_sort_bv_get_size(cvc5_term_get_sort(t));
}

/* Static shifts: shift by a constant amount.  Note that cvc5 gives a
   total semantics (shifting by the width or more yields zero/arithmetic
   fill), matching STP's vc_bvLeftShiftExpr/vc_bvRightShiftExpr. */
Cvc5Term bsc_cvc5_mk_bv_shl_const(BscCvc5Context* ctx,
                                  Cvc5Term a, uint32_t amount) {
  Cvc5Term n = cvc5_mk_bv_uint64(ctx->tm, bv_size(a), amount);
  return bsc_cvc5_mk_bv_shl(ctx, a, n);
}

Cvc5Term bsc_cvc5_mk_bv_lshr_const(BscCvc5Context* ctx,
                                   Cvc5Term a, uint32_t amount) {
  Cvc5Term n = cvc5_mk_bv_uint64(ctx->tm, bv_size(a), amount);
  return bsc_cvc5_mk_bv_lshr(ctx, a, n);
}

/* ------------------------------------------------------------------ */
/* Concatenation, extraction and extension                              */

Cvc5Term bsc_cvc5_mk_bv_concat(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b) {
  return mk_binop(ctx, CVC5_KIND_BITVECTOR_CONCAT, a, b);
}

Cvc5Term bsc_cvc5_mk_bv_extract(BscCvc5Context* ctx,
                                Cvc5Term a, uint32_t upper, uint32_t lower) {
  uint32_t idxs[2] = {upper, lower};
  Cvc5Op op = cvc5_mk_op(ctx->tm, CVC5_KIND_BITVECTOR_EXTRACT, 2, idxs);
  return cvc5_mk_term_from_op(ctx->tm, op, 1, &a);
}

/* Sign-extend (or truncate, matching STP's vc_bvSignExtend) so that the
   result is exactly "total_width" bits wide. */
Cvc5Term bsc_cvc5_mk_bv_sign_extend_to(BscCvc5Context* ctx,
                                       Cvc5Term a, uint32_t total_width) {
  uint32_t width = bv_size(a);
  if (total_width < width) {
    /* STP truncates in this case, so do the same */
    return bsc_cvc5_mk_bv_extract(ctx, a, total_width - 1, 0);
  } else {
    uint32_t idxs[1] = {total_width - width};
    Cvc5Op op = cvc5_mk_op(ctx->tm, CVC5_KIND_BITVECTOR_SIGN_EXTEND, 1, idxs);
    return cvc5_mk_term_from_op(ctx->tm, op, 1, &a);
  }
}

/* (extract idx idx) a == #b1, as a Bool */
Cvc5Term bsc_cvc5_mk_bv_bool_extract_one(BscCvc5Context* ctx,
                                         Cvc5Term a, uint32_t idx) {
  Cvc5Term bit = bsc_cvc5_mk_bv_extract(ctx, a, idx, idx);
  Cvc5Term one = cvc5_mk_bv_uint64(ctx->tm, 1, 1);
  return bsc_cvc5_mk_eq(ctx, bit, one);
}
