#define RTLD_NOW 0x00002
#define RTLD_GLOBAL 0x00100

// readability typedefs
using Variable = void;
using Frame = void;

// function pointer_types
using send_command_t = void*(*)(char*);
using set_frame_t = void*(*)(Frame*);
using last_compilation_result_t = int(*)();

// load shared library
void* handle = (void*) dlopen("/home/tehrengruber/Development/EnhancedLLDB/cling_lldb/build/liblldbclingbridge.so", RTLD_NOW | RTLD_GLOBAL);

if (!handle) {
    (void) printf("Cannot open library: %s\n", (char*) dlerror());
    (void) exit(1);
}

send_command_t send_command = (send_command_t) dlsym(handle, "send_command");
set_frame_t set_frame = (set_frame_t) dlsym(handle, "set_frame");
last_compilation_result_t get_last_compilation_result = (last_compilation_result_t) dlsym(handle, "get_last_compilation_result");

