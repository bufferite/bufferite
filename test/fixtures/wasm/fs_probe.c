#include <stdio.h>

// Fixture: mencoba membuka file host. Tanpa preopen WASI, fopen harus gagal.
int main(void) {
  FILE *file = fopen("/etc/passwd", "r");
  if (file == NULL) {
    printf("blocked");
    return 0;
  }
  printf("opened");
  fclose(file);
  return 0;
}
