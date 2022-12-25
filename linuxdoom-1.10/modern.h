#ifndef MODERN_H_
#define MODERN_H_

#define CEIL_DIV(n, d) (((n) + (d) - 1) / (d))
#define ALIGN(n, a) (CEIL_DIV(n, a) * (a))

#endif // MODERN_H_