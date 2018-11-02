#include <vector>
#include <iostream>

#include "cling/Interpreter/Interpreter.h"
#include "cling/Interpreter/Value.h"
#include "cling/UserInterface/UserInterface.h"
#include "clang/AST/Type.h"
#include "clang/AST/DeclCXX.h"
#include <csignal>
#include <cstdlib>
#include <unistd.h>
#include <string>
#include <sstream>
#include <memory>

namespace Defrustrator {

// instance of the current interpreter
static std::unique_ptr<cling::Interpreter> interpreter;

static const char* LLVMRESDIR = "/home/tehrengruber/Downloads/cling_2018-10-29_ubuntu17.10";

cling::Interpreter::CompilationResult last_compilation_result;

}

// c interface
extern "C" {
    using namespace Defrustrator;
    /*
     * Cling interface
     */
    void reset_interpreter() {
        #ifdef DEBUG
        std::cout << "[DEBUG] reset_interpreter" << std::endl;
        #endif
        int argc = 4;
        char const* * argv = new const char*[4];
        argv[0] = "dummy"; // todo: use executablename path from lldb
        argv[1] = "-I/home/tehrengruber/Development/EnhancedLLDB/cling_compile_test/inst/include";
        argv[2] = "-I/usr/include/eigen3/";
		argv[3] = "-I/home/tehrengruber/Development/EnhancedLLDB/cling_lldb/include/";
        interpreter.reset(new cling::Interpreter(argc, argv, LLVMRESDIR));
        interpreter->declare("#include <Eigen/Dense>");
        interpreter->declare("#include <type_traits>");
        interpreter->declare("#include <iostream>");
    }

    int get_last_compilation_result() {
        switch (last_compilation_result) {
            case cling::Interpreter::CompilationResult::kSuccess:
                return 0;
            case cling::Interpreter::CompilationResult::kFailure:
                return 1;
            case cling::Interpreter::CompilationResult::kMoreInputExpected:
                return 2;
            default:
                std::cerr << "Unexpected value for last_compilation_result. Please submit a bug report." << std::endl;
                std::exit(1);
                break;
        }
        return -1;
    }

    void* send_command(char* command) {
        #ifdef DEBUG
        std::cout << "[DEBUG] send_command" << std::endl;
        #endif

        std::unique_ptr<cling::Value> result(new cling::Value);
        if (!interpreter) {
            reset_interpreter();
            interpreter->declare("#include \"value_printer.hpp\"");
        }
        last_compilation_result = interpreter->process(command, result.get(), nullptr, false);

        return result->hasValue() ? result->template getAs<void*>() : nullptr;
    }
}
