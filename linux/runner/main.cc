// ABOUTME: Starts the Linux GTK application host for Eye Inspector.
// ABOUTME: Hands command line startup to the Flutter runner application.
#include "my_application.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
