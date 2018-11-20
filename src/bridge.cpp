#include <vector>
#include <iostream>

#include "cling/Interpreter/Interpreter.h"
#include "cling/Interpreter/Value.h"
#include "cling/Interpreter/LookupHelper.h"
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

static const char* LLVMRESDIR = DEFRUSTRATOR_BASE_PATH "/bin/cling/";

cling::Interpreter::CompilationResult last_compilation_result;

}

// c interface
extern "C" {
    using namespace Defrustrator;

    void defrustrator_reset_interpreter() {
        // todo: obtain arguments from plugin/executable-conf
        #ifdef DEBUG
        std::cout << "[DEBUG] reset_interpreter" << std::endl;
        #endif
        int argc = 4;
        char const** argv = new const char*[3];
        argv[0] = "dummy"; // todo: use executablename path from lldb
        argv[1] = "-I" DEFRUSTRATOR_BASE_PATH "/bin/cling/include";
        argv[2] = "-I" DEFRUSTRATOR_BASE_PATH "/include";
        argv[3] = "-std=c++17";
        interpreter.reset(new cling::Interpreter(argc, argv, LLVMRESDIR));
        interpreter->declare("#include <type_traits>");
        interpreter->declare("#include <iostream>");
    }

    void defrustrator_init() {
        if (!interpreter) {
            defrustrator_reset_interpreter();
            interpreter->declare("#include \"value_printer.hpp\"");
        }
    }

    void defrustrator_add_include_path(char* path) {
        defrustrator_init();
        interpreter->AddIncludePath(path);
    }

    int defrustrator_get_last_compilation_result() {
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

    bool defrustrator_type_exists(char* type) {
        defrustrator_init();
        const cling::LookupHelper& lookup = interpreter->getLookupHelper();
        clang::QualType cl_A = lookup.findType(type, cling::LookupHelper::WithDiagnostics);
        return !cl_A.isNull();
    }

    void* defrustrator_send_command(char* command) {
        #ifdef DEBUG
        std::cout << "[DEBUG] send_command" << std::endl;
        #endif
        defrustrator_init();

        std::unique_ptr<cling::Value> result(new cling::Value);
        last_compilation_result = interpreter->process(command, result.get(), nullptr, false);

        return result->hasValue() ? result->template getAs<void*>() : nullptr;
    }
}
