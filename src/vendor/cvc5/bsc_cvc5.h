/*
 * Thin C shim over the cvc5 C API (see bsc_cvc5.c).
 *
 * All cvc5 objects (sorts, terms) are owned by the context's term
 * manager and stay alive until bsc_cvc5_delete().
 */

#ifndef BSC_CVC5_H
#define BSC_CVC5_H

#include <stdint.h>

#include <cvc5/c/cvc5.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct BscCvc5Context BscCvc5Context;

BscCvc5Context* bsc_cvc5_new(void);
void bsc_cvc5_delete(BscCvc5Context* ctx);
const char* bsc_cvc5_get_version(BscCvc5Context* ctx);

void bsc_cvc5_push(BscCvc5Context* ctx);
void bsc_cvc5_pop(BscCvc5Context* ctx);
void bsc_cvc5_assert(BscCvc5Context* ctx, Cvc5Term e);

/* 0 = invalid (satisfiable), 1 = valid (unsatisfiable), 3 = unknown */
uint8_t bsc_cvc5_query(BscCvc5Context* ctx, Cvc5Term e);

Cvc5Sort bsc_cvc5_mk_bool_sort(BscCvc5Context* ctx);
Cvc5Sort bsc_cvc5_mk_bv_sort(BscCvc5Context* ctx, uint32_t width);

Cvc5Term bsc_cvc5_mk_var(BscCvc5Context* ctx, const char* name, Cvc5Sort sort);
Cvc5Term bsc_cvc5_mk_true(BscCvc5Context* ctx);
Cvc5Term bsc_cvc5_mk_false(BscCvc5Context* ctx);
Cvc5Term bsc_cvc5_mk_bv_const_uint64(BscCvc5Context* ctx,
                                     uint32_t width, uint64_t val);
Cvc5Term bsc_cvc5_mk_bv_const_dec_str(BscCvc5Context* ctx,
                                      uint32_t width, const char* dec);

Cvc5Term bsc_cvc5_mk_not(BscCvc5Context* ctx, Cvc5Term a);
Cvc5Term bsc_cvc5_mk_and(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_or(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_xor(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_and_n(BscCvc5Context* ctx,
                           uint32_t n, const Cvc5Term args[]);
Cvc5Term bsc_cvc5_mk_or_n(BscCvc5Context* ctx,
                          uint32_t n, const Cvc5Term args[]);
Cvc5Term bsc_cvc5_mk_implies(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_iff(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_eq(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_ite(BscCvc5Context* ctx,
                         Cvc5Term c, Cvc5Term t, Cvc5Term f);
Cvc5Term bsc_cvc5_mk_bool_to_bv(BscCvc5Context* ctx, Cvc5Term b);

Cvc5Term bsc_cvc5_mk_bv_add(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_sub(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_mul(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_udiv(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_urem(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_sdiv(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_srem(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_smod(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_neg(BscCvc5Context* ctx, Cvc5Term a);

Cvc5Term bsc_cvc5_mk_bv_ult(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_ule(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_ugt(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_uge(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_slt(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_sle(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_sgt(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_sge(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);

Cvc5Term bsc_cvc5_mk_bv_and(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_or(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_xor(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_not(BscCvc5Context* ctx, Cvc5Term a);

Cvc5Term bsc_cvc5_mk_bv_shl(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_lshr(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_ashr(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_shl_const(BscCvc5Context* ctx,
                                  Cvc5Term a, uint32_t amount);
Cvc5Term bsc_cvc5_mk_bv_lshr_const(BscCvc5Context* ctx,
                                   Cvc5Term a, uint32_t amount);

Cvc5Term bsc_cvc5_mk_bv_concat(BscCvc5Context* ctx, Cvc5Term a, Cvc5Term b);
Cvc5Term bsc_cvc5_mk_bv_extract(BscCvc5Context* ctx,
                                Cvc5Term a, uint32_t upper, uint32_t lower);
Cvc5Term bsc_cvc5_mk_bv_sign_extend_to(BscCvc5Context* ctx,
                                       Cvc5Term a, uint32_t total_width);
Cvc5Term bsc_cvc5_mk_bv_bool_extract_one(BscCvc5Context* ctx,
                                         Cvc5Term a, uint32_t idx);

#ifdef __cplusplus
}
#endif

#endif /* BSC_CVC5_H */
