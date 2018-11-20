#define RTLD_NOW 0x00002
#define RTLD_GLOBAL 0x00100

// readability typedefs
using Variable = void;
using Frame = void;

// function pointer_types
using send_command_t = void*(*)(char*);
using last_compilation_result_t = int(*)();
using type_exits_result_t = bool(*)(char*);
using add_include_path_t = void(*)(char*);

// load shared library
void* handle = (void*) dlopen("DEFRUSTRATOR_BASE_PATH/build/liblldbclingbridge.so", RTLD_NOW | RTLD_GLOBAL);

if (!handle) {
    (void) printf("Cannot open library: %s\n", (char*) dlerror());
    (void) exit(1);
}

send_command_t send_command = (send_command_t) dlsym(handle, "defrustrator_send_command");
last_compilation_result_t get_last_compilation_result = (last_compilation_result_t) dlsym(handle, "defrustrator_get_last_compilation_result");
type_exits_result_t type_exists = (type_exits_result_t) dlsym(handle, "defrustrator_type_exists");
add_include_path_t add_include_path = (add_include_path_t) dlsym(handle, "defrustrator_add_include_path");