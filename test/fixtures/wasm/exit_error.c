#include <stdio.h>

// Fixture: exit non-zero dengan pesan di stderr.
int main(void) {
  fputs("boom dari plugin", stderr);
  return 3;
}
