/* Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org> */
/* SPDX-License-Identifier: BSD-3-Clause */

#ifndef xlocale_wrapper_h
#define xlocale_wrapper_h

#include <wchar.h>

#ifdef __cplusplus
extern "C" {
#endif

// Wrapper functions for xlocale functionality
int vt_wcwidth_l(wchar_t wc, void *locale);
void *vt_newlocale(int mask, const char *locale, void *base);
void vt_freelocale(void *locale);

// Constants
#if __APPLE__
#define LC_CTYPE_MASK (1 << 1)
#endif

#ifdef __cplusplus
}
#endif

#endif /* xlocale_wrapper_h */