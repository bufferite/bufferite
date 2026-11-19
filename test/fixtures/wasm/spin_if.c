#include <stdio.h>
#include <string.h>

// Fixture: loop bila argv[1] == "spin", selain itu echo stdin.
int main(int argc, char **argv) {
  if (argc > 1 && strcmp(argv[1], "spin") == 0) {
    volatile unsigned long counter = 0;
    for (;;) {
      counter++;
    }
  }
  int c;
  while ((c = getchar()) != EOF) {
    putchar(c);
  }
  return 0;
}
