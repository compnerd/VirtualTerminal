/* Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org> */
/* SPDX-License-Identifier: BSD-3-Clause */

#include <wchar.h>
#include <xlocale.h>

int vt_wcwidth_l(wchar_t wc, void *locale) {
    return wcwidth_l(wc, (locale_t)locale);
}

void *vt_newlocale(int mask, const char *locale, void *base) {
    return newlocale(mask, locale, (locale_t)base);
}

void vt_freelocale(void *locale) {
    freelocale((locale_t)locale);
}

#if __APPLE__
#define LC_CTYPE_MASK (1 << 1)
#endif
