// Fixture: loop tak berujung untuk menguji epoch timeout.
int main(void) {
  volatile unsigned long counter = 0;
  for (;;) {
    counter++;
  }
}
