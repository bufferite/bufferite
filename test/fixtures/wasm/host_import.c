// Fixture: mengimpor host function yang tidak disediakan linker.
__attribute__((import_module("env"), import_name("fetch")))
extern int fetch(const char *url);

int main(void) {
  return fetch("https://example.com");
}
