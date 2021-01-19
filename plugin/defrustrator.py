#!/usr/bin/python
import os
import lldb
import threading
import time
import re
import ctypes
import json
from prompt_toolkit import prompt
from prompt_toolkit.history import FileHistory
from prompt_toolkit.lexers import PygmentsLexer
from pygments.lexers.c_cpp import CppLexer
from os.path import expanduser

# todo: add command to add include paths to cling
# todo: how about rvalue references
# todo: add prompt toolkit and pygments to the requirements in the readme
# todo: hook at run to load_config and include headers
# todo: find all types that are declared, but not available in the interpreter
# todo: if the binary was compiled with a different compiler or different flags unexpected things might happen
# todo: find a way to handle the `this` variable if inside a class scope
# todo: command to add compile definitions
#  for example printing an eigen vector gives incorrect results if a different c++ standard was used
#  see lf.examples.quad.quad_demo node_coords when plugin uses c++11
# todo: add commands to (import headers and libraries, add include paths)
# todo: add help for subcommands
# todo: autocompletion for commands (might not be possible)
# todo: occasionally lldbinit is not changed correctly
# todo: global variables don't work (idea: put wrapper code inside a unique namespace and define them there
#  i.e. namespace namespace wrapper { auto& global_var = ...; /* actual code */ }

#
# Global variables
#
cling_path = os.path.dirname(__file__) + "/../bin/cling"
base_path = os.path.dirname(__file__) + "/../"

history_file = expanduser("~/.lldb-defrustrator-history")
current_process_id = None

type_cache = {}

# read bridge code
with open(base_path + '/src/plugin_bridge.cpp', 'r') as file:
    bridge_code = file.read()
bridge_code=bridge_code.replace("DEFRUSTRATOR_BASE_PATH", base_path)

class EvaluationThread(threading.Thread):
    def __init__(self, frame, code, options):
        threading.Thread.__init__(self)
        self.frame = frame
        self.code = code
        self.options = options
        self.result = None
    def run(self):
        self.result = self.frame.EvaluateExpression(self.code, self.options)

class NoFrameException(RuntimeError):
    def __init__(self):
        super(RuntimeError, self).__init__("No frame here")

import signal
import sys
from ctypes import *
libc = cdll.LoadLibrary("libc.so.6")

"""
Ensure that the currently evaluated expression is interrupted
/when ctrl+c is pressed
"""
class InterruptGuard:
    # since we can not restore the SIGINT handler to None we
    #  use this lambda function as a signal handler to identify
    #  that no other SIGINT handler was set from python
    dummy_handler = lambda a, b: 1

    def __init__(self, debugger):
        self.debugger = debugger
        self.old_handler = None
        self.old_handler_c = None

    def handler(self, signal, frame):
        process = self.debugger.GetSelectedTarget().GetProcess()
        process.SendAsyncInterrupt()

    """
    check if we have a signal handler defined in python
    """
    def has_sigint_handler(self):
        return (signal.getsignal(signal.SIGINT) != None
                and signal.getsignal(signal.SIGINT) != InterruptGuard.dummy_handler)

    def __enter__(self):
        # store previous (c) signal handler
        if not self.has_sigint_handler():
            # first set SIG_IGN signal while retrieving the current one
            self.old_handler_c = libc.signal(signal.SIGINT, signal.SIG_IGN)
            # then restore the one we just got
            libc.signal(signal.SIGINT, self.old_handler_c)
        else:
            print("Warning: another SIGINT handler was already registered from python. You are running untested code.")

        # register signal python handler
        self.old_handler = signal.signal(signal.SIGINT, lambda signal, frame: self.handler(signal, frame))

    def __exit__(self, type, value, traceback):
        # remove previously registered signal handler
        signal.signal(signal.SIGINT, InterruptGuard.dummy_handler)
        # restore old signal handler
        if self.has_sigint_handler():
            signal.signal(signal.SIGINT, self.old_handler)
            self.old_handler = None
        elif self.old_handler_c != None:
            # if no handler was found in python restore the one from c
            # todo: this leads to a segfault in the lldb prompt
            #libc.signal(signal.SIGINT, self.old_handler_c)
            self.old_handler_c = None

def __lldb_init_module (debugger, dict):
    debugger.HandleCommand('command script add -f defrustrator.cling cling')
    print("The \"cling\" command has been added successfully")

def help():
    return '''The following subcommands are supported:
        include ("<file>"/<<file>>) -- Include source file
        repl -- Start cling repl
        print <expr> -- Print expressions return value using operator<< if possible
        expression <expr> -- Evaluate expression
        include_directories <dir1>, <dir2>, ... -- Add include directories
        load_config -- Load configuration of include directories, compile definitions, headers
    '''

def lldb_evaluate(debugger, code, interruptable=True):
    global bridge_code, current_process_id
    # prepend bridge code
    code = bridge_code + "\n//\n// DYNAMIC CODE\n//\n" + str(code)
    target = debugger.GetSelectedTarget()
    process = target.GetProcess()
    thread = process.GetSelectedThread()
    frame = thread.GetSelectedFrame()
    if not frame.IsValid():
        print("no frame here")
        return
    if process.GetUniqueID() != current_process_id:
        current_process_id=process.GetUniqueID()
        load_config(debugger)

    # start a thread that runs until the currently evaluated expression returns.
    # since the expression is evaluated without any timeout and
    #  lldb will not interrupt it on ctrl+c we add a signal handler
    #  that interrupts the currently running expression when ctrl+c is pressed
    options = lldb.SBExpressionOptions()
    options.SetTimeoutInMicroSeconds(0) # no timeout
    options.SetUnwindOnError(True)

    if interruptable:
        thread = EvaluationThread(frame, code, options)
        thread.start() # start the thread
        # spin until thread finishes and use InterruptGuard to interrupt the process
        #  when ctrl+c is pressed
        #with InterruptGuard(debugger) as interrupt_guard:
        while thread.isAlive():
            time.sleep(0.05)

        thread.join()
        return thread.result
    else:
        return frame.EvaluateExpression(code, options)

def type_exists(debugger, type_name):
    if len(type_name)>=17 and type_name[0:17] == "(anonymous class)":
        return False
    if type_name in type_cache:
        return type_cache[type_name]
    type_name = type_name.replace("\n", "\\n").replace('"', '\\"')
    result = lldb_evaluate(debugger, "(bool) type_exists(\"" + type_name + "\");", False)
    assert(result.GetError().Success())
    if result.GetValue()=="true": # todo: not a clean way to extract the value
        type_cache[type_name] = True
    return result.GetValue()=="true"

def include_directories(debugger, dirs):
    for dir in dirs:
        result = lldb_evaluate(debugger, "add_include_path(\"" + dir + "\");")
        # todo: add error handling
        #if not result.GetError().Success():
        #    print("Warning: Failed to add to include paths {}".format(dir))

def eval_expr(debugger, code, options={}):
    """
    Evaluate `code` in cling interpreter
    """
    default_options = {
        "global": False
    }
    default_options.update(options)
    options = default_options

    frame = debugger.GetSelectedTarget().GetProcess().GetSelectedThread().GetSelectedFrame()
    if not frame.IsValid():
        raise NoFrameException()

    # todo: test that everything works correctly when the frame changes and both frames contain the same variables
    wrapper_code = ""

    # todo: test that only the inner most variable is used (SBValue::IsInScope?)
    if not options["global"]:
        # compute for each variable a number describing it's depth in terms of blocks
        # i.e. a variable in the current block has depth 0, one in the parent block depth 1 and so on

        # fetch all blocks
        blocks = []
        current_block = frame.GetBlock()
        while current_block.IsValid():
            blocks.append(current_block)
            current_block = current_block.GetParent()
        # get variables in each block
        blocks_vars = map(lambda block: block.GetVariables(frame, True, True, False, True), blocks)
        # dictionary assigning each variable (key is an id) a depth
        var_depths = {}
        # iterate over all variables
        for var in frame.GetVariables(True, True, False, True):
            # set depth to maximum integer value in the beginning since global variable will not be found in any block
            var_depths[var.GetID()] = 2147483647
            for i, block_vars in enumerate(blocks_vars):
                for block_var in block_vars:
                    if var.GetID() == block_var.GetID():
                        var_depths[var.GetID()] = i
        # dictionary assigning each variable name an array containing it's depth and an SBValue objects
        vars = {}
        for var in frame.GetVariables(True, True, False, True):
            if not var.GetName() in vars:
                vars[var.GetName()] = (var_depths[var.GetID()], var)
            else:
                if var_depths[var.GetID()] < vars[var.GetName()][0]:
                    vars[var.GetName()] = (var_depths[var.GetID()], var)

        # write wrapper code making variables accessible
        for (_, (depth, var)) in vars.items():
            address = frame.EvaluateExpression("&"+var.GetName()).GetValue()
            if var == "this":
                print("Note: variable `this` skipped")

            var_type = get_type_str(var.GetType())
            if type_exists(debugger, var_type):
                # remove reference qualifier
                #  note that the following code lead to severe problems if compilation failed (i.e. when an
                #  undeclared identifier has been used)
                #  "std::add_lvalue_reference<{type}>::type {name} = "
                if var_type[-1]=="&":
                    var_type=var_type[:-1]
                wrapper_code += ("{type}& {name} = "
                                "*reinterpret_cast<std::remove_reference<{type}>::type*>((void*){address});\n") \
                    .format(name=var.GetName(), type=var_type, address=address)
            else:
                print("Warning: variable `{name}` with type `{type}` skipped".format(name=var.GetName(), type=var_type))

        code = ("{{\n"
                "  // Wrapper code\n"
                "  {wrapper_code}\n"
                "  // Code\n"
                "  {code}\n"
                "}}").format(wrapper_code=wrapper_code, code=code)

    # escape characters
    code = code.replace("\n", "\\n").replace('"', '\\"')

    # send code to the interpreter
    result = lldb_evaluate(debugger, "send_command(\"" + code + "\");")

    # check the compilation result
    compilation_result = frame.EvaluateExpression("(int) defrustrator_get_last_compilation_result()").GetValue()
    if compilation_result == "0":
        pass
    elif compilation_result == "1":
        print("Compilation failed")
    elif compilation_result == "2":
        print("More input expected")
    else:
        raise Exception()

    return result

def get_type_str(raw_type):
    assert(isinstance(raw_type, lldb.SBType))
    # this is a really nasty fix for the fact that lldb only gives
    #  us Type* even if we have Ns::Type*, but since we need the full
    #  type we strip of all qualifiers replace Type with Ns::Type
    #  and put on the qualifiers again
    # check if we have a function
    if raw_type.IsFunctionType():
        raise NotImplementedError("An unexpected case has occurred. Please fill in a bug report how you triggered this.")
    # check if we have a function pointer
    if raw_type.IsPointerType() and raw_type.GetPointeeType().IsFunctionType():
        func_type = raw_type.GetPointeeType()
        # get the correct type string for the return type and all arguments
        return_type = get_type_str(raw_type.GetPointeeType().GetFunctionReturnType())
        # get correct type string for all arguments
        argument_types = []
        for arg in raw_type.GetPointeeType().GetFunctionArgumentTypes():
            argument_types.append(get_type_str(arg))
        return return_type + "(*)(" + ", ".join(argument_types) + ")"

    # unwrap type (get inner most pointee)
    unwrapped_type = raw_type
    while unwrapped_type.IsPointerType():
        unwrapped_type = unwrapped_type.GetPointeeType()

    # workarround for a bug in lldb where template parameters of
    #  type int are parsed as an unsigned int
    # if unwrapped_type is already a canonical type (e.g. all typedefs expanded)
    #  and we have some template parameters we check if they are of type
    #  int and have a value higher than std::numeric_limits<int>::max()
    #  we fix the template parameter
    if unwrapped_type.GetCanonicalType().GetName() == unwrapped_type.GetName() and unwrapped_type.GetNumberOfTemplateArguments() > 0:
        canonical_unwrapped_type = unwrapped_type.GetCanonicalType()
        canonical_unwrapped_type_name = canonical_unwrapped_type.GetName()
        # first get the name of the type without template arguments
        class_name = re.sub(r"(.*?)<(.*)", r"\1", unwrapped_type.GetCanonicalType().GetName())
        # get all template arguments (for value arguments we want the value not the type)
        tpl_args = []
        arg_begin=canonical_unwrapped_type_name.find('<')+1
        depth=0
        for pos in xrange(0, len(canonical_unwrapped_type_name)):
            if canonical_unwrapped_type_name[pos] == "<":
                depth += 1
            if canonical_unwrapped_type_name[pos] == ">":
                depth -= 1
            if canonical_unwrapped_type_name[pos] == "," and depth == 1:
                tpl_args.append(canonical_unwrapped_type_name[arg_begin:pos])
                arg_begin = pos+1
            if canonical_unwrapped_type_name[pos] == ">" and depth == 0:
                tpl_args.append(canonical_unwrapped_type_name[arg_begin:pos])
                depth-=1
                break
        #print(canonical_unwrapped_type_name)
        #print(tpl_args)
        #tpl_args = canonical_unwrapped_type.GetName()[len(class_name)+1:-1].split(',') # here we want the value
        tpl_args_type = unwrapped_type.template_args # here we want the type
        assert(len(tpl_args) == canonical_unwrapped_type.GetNumberOfTemplateArguments())

        # todo: this is not very generic yet
        for i in range(len(tpl_args)):
            arg = tpl_args[i].strip()
            typ = tpl_args_type[i]
            if arg != "int" and typ == typ.GetBasicType(lldb.eBasicTypeInt) and int(arg)>=2**31:
                tpl_args[i] = ctypes.c_int(int(arg)).value

        return class_name + "<" + ", ".join(str(a) for a in tpl_args) + ">"

    # check wether we can find the unqualified name of type of the "inner most" pointee
    #  if that is not the case we assume that we have we've got something
    #  like Ns::Type in the inner most type but only Type* one level higher 
    #  as such we replace Type with Ns::Type
    if not re.search(re.escape(unwrapped_type.GetUnqualifiedType().GetName()), raw_type.GetName()):
        stripped_inner_most = re.sub(".*?([^:]+)$", r"\1", unwrapped_type.GetUnqualifiedType().GetName())
        return re.sub(re.escape(stripped_inner_most), unwrapped_type.GetUnqualifiedType().GetName(), raw_type.GetName())

    return raw_type.GetName() # fallback

def get_variables(debugger):
    """Get all variables visible in the current frame"""
    frame = debugger.GetSelectedTarget().GetProcess().GetSelectedThread().GetSelectedFrame()
    if not frame.IsValid():
        raise NoFrameException()

    # todo: test that only the inner most variable is used (SBValue::IsInScope?)
    variables = {}
    for var in frame.GetVariables(True, True, False, True):
        variables[var.GetName()] = var

    return variables

def repl(debugger, options):
    # read input and evaluate commands
    try:
        history = FileHistory(history_file)
        while True:
            # read command
            cmd = prompt(u"(cling) ", lexer=PygmentsLexer(CppLexer), history=history)
            # evaluate command
            eval_expr(debugger, cmd, options)
    except KeyboardInterrupt:
        1
    finally:
        1

def print_expr(debugger, expr, options):
    # todo: check if we should print a result
    # todo: omit copy
    #  see cling::ValuePrinterSynthesizer::tryAttachVP for the actual check which expressions should be printed
    #  see cling::IncrementalParser::ParseInternal which parses the code and transforms the code
    #   using the ValuePrinterSynthesizer
    expr = ("{"
            "  auto _defrustr_result = " + expr + ";\n"
            "  Defrustrator::ValuePrinter<decltype(_defrustr_result)>::print(_defrustr_result);"
            " }")
    eval_expr(debugger, expr, options)

def include_file(debugger, filename):
    eval_expr(debugger, "#include {}".format(filename), {"global": True})

def load_config(debugger):
    default_config = {
        "include_directories": [],
        "compile_definitions": [],
        "headers": []
    }
    target = debugger.GetSelectedTarget()
    for m in target.module_iter():
        conf_path = str(m.GetFileSpec())+".defrustrator.json"
        if os.path.isfile(conf_path):
            print("Loading config {}".format(conf_path))
            with open(conf_path, "r") as read_file:
                # parse config
                conf = json.load(read_file)
                conf_stash = default_config.copy()
                conf_stash.update(conf)
                conf = conf_stash

                print("Adding include directories {}".format(' '.join(conf["include_directories"])))
                include_directories(debugger, conf["include_directories"])
                print("Loading compile_definitions {}".format(' '.join(conf["compile_definitions"])))
                for comp_def in conf["compile_definitions"]:
                    pos = comp_def.find("=")
                    if pos == -1:
                        code = "#define {}".format(comp_def)
                    else:
                        code = "#define {} {}".format(comp_def[0:pos], comp_def[pos+1:])
                    #print(code)
                    eval_expr(debugger, code, {"global": True})
                print("Loading headers {}".format(' '.join(conf["headers"])))
                for header in conf["headers"]:
                    if header[0] != "\"" and header[0] != "<":
                        header = "\""+header+"\""
                    include_file(debugger, header)


def parse_command_options(commands):
    options = {}
    pos = 0
    while pos < len(commands) and commands[pos][0:2] == "--":
        keyword_arg = commands[pos][2:]
        options[keyword_arg] = True
        pos+=1
    return pos, options

def cling(debugger, command, result, dict):
    if len(debugger.GetSelectedTarget().FindSymbols("dlopen")) == 0:
        print("Error: target needs to be linked with libdl (add -ldl to compiler invocation)")
        return

    #
    # parse command
    #
    commands = command.split(' ')
    pos, options = parse_command_options(commands[1:])

    if len(commands) < 1 or commands[0] == '':
        print(help())
        return

    if commands[0] == "start":
        start()
    elif commands[0] == "include":
        include_file(debugger, commands[1])
    elif commands[0] == "include_directories":
        include_directories(debugger, commands[1:])
    elif commands[0] == "load_config":
        load_config(debugger)
    elif commands[0] == "type_exists":
        type_exists(debugger, ' '.join(commands[1:]))
    elif commands[0] == "repl":
        repl(debugger, options)
    elif commands[0] == "expression" or commands[0] == "expr" or commands[0] == "e":
        eval_expr(debugger, ' '.join(commands[pos+1:]), options)
    elif commands[0] == "print" or commands[0] == "p":
        print_expr(debugger, ' '.join(commands[pos+1:]), options)
    else:
        print(help())

    return None

