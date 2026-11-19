#include <ctype.h>
#include <stdio.h>

// Fixture ABI tier wasm: baca stdin, tulis versi uppercase ke stdout.
int main(void) {
  int c;
  while ((c = getchar()) != EOF) {
    putchar(toupper(c));
  }
  return 0;
}
