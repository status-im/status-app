// Bridges StatusQ's C++ registerStatusQTypes() to a C-linkage symbol the
// (C-compiled) Nim benchmark can call.
extern void registerStatusQTypes();
extern "C" void bench_registerStatusQTypes() { registerStatusQTypes(); }
