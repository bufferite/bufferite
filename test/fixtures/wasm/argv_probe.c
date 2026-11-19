#include <stdio.h>

// Fixture: cetak argc dan dua argumen pertama (ABI argv).
int main(int argc, char **argv) {
  printf("%d|%s|%s", argc, argc > 1 ? argv[1] : "",
         argc > 2 ? argv[2] : "");
  return 0;
}
