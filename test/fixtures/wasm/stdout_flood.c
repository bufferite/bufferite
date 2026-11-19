#include <stdio.h>

// Fixture: membanjiri stdout melewati batas keluaran sandbox.
int main(void) {
  for (int i = 0; i < 32 * 1024; i++) {
    fputs("0123456789abcdef", stdout);
  }
  return 0;
}
