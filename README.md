# Defrustrator

LLDB Plugin based on cling to allow evaluation of almost all c++ expressions while debugging, overcoming most limitations
of LLDB's own expression evaluation features.

__WARNING__ This is an alpha version! Be careful and do not trust the results.

__Installation__

```
bash -c "$(wget https://raw.githubusercontent.com/tehrengruber/Defrustrator/master/scripts/install.sh -O -)"
```

__Help__
```
The following subcommands are supported:
    include ("<file>"/<<file>>) -- Include source file
    repl -- Start cling repl
    print <expr> -- Print expressions return value using operator<< if possible
    expression <expr> -- Evaluate expression
    include_directories <dir1>, <dir2>, ... -- Add include directories
    load_config -- Load configuration of include directories, compile definitions, headers
```

__Demo__
```
(lldb) cling repl
(cling) #include <iostream>
(cling) std::cout << "Hello World!" << std::endl;
Hello World!
```

```
(lldb) cling include_directories /usr/include/eigen3/
(lldb) cling include <Eigen/Dense>
(lldb) cling repl
(cling) Eigen::VectorXd v(3);
(cling) v.setConstant(1);
(lldb) cling p v
1
1
1
```

## How it works

This plugin consists of three components. A python extension handling the interaction with LLDB, some c code to be 
executed inside LLDB to load a shared library, and said library providing a minimal interface to send commands to the 
cling interpreter, which by itself is also run in the same process. Since the interpreter is run in the same process
all variables can be accessed if the type and memory address is known.

## Usage

__include ("<file>"/<<file>>)__ Include source files

```
(lldb) cling include <iostream>
```

__repl__ Drop to cling repl

Options:
 - `--global`: Evaluate in global scope (variables of the executable are not accessible)

```
(lldb) cling repl
(cling) std::cout << "Hello world" << std::endl;
Hello world
```

__print <expr>__ Print expressions return value using operator<< if possible

Options:
 - `--global`: Evaluate in global scope (variables of the executable are not accessible)

```
(lldb) run
...
-> 2   	  const int a = 1;
...
(lldb) cling print a
0
```

__expression <expr>__ Evaluate expression

Options:
 - `--global`: Evaluate in global scope (variables of the executable are not accessible)

```
(lldb) cling expression int a=1;
0
```

__include_directories \<dir1\>, \<dir2\>, ...__ Add include directories

```
(lldb) cling include_directories /usr/include/eigen3
```

__load_config \<file\>__ Load configuration file

Include directories, compiler flags, headers to be included can be stored to a json file loading when the first cling
command is run.

```
{
  "include_directories": ["/usr/include/eigen3"],
  "compile_definitions": ["SOMEVAR=1"],
  "headers": ["<Eigen/Dense>"]
}
```

## Limitations

- The line numbers reported are not correct.

- If compilation fails for some commands consecutive commands may also fail to compile even though they are correct.

- Variables declared in local scope are only accessible in that statement

    ```
    (lldb) cling repl
    (cling) int a=1;
    (cling) a;
    input_line_12:12:3: error: use of undeclared identifier 'a'
      a;
      ^
    Compilation failed
    ```

- If inclusion of a header fails since the corresponding include directory was not added beforehand reincluding the
  header might not work.

- In case a variable is declared and compilation fails it might not be possible to redeclare it.

- All types must be completly defined, i.e. by including the corresponding header, before they can be accessed
  or an error will be thrown.

  Consider the following code:
  ```
  struct A{};
  int main() {
    A a;
  }
  ```
  Then trying to print A will fail as shown below:
  ```
  $ lldb example
  (lldb) break set -n main
  The "cling" command has been added successfully
  (lldb) target create "a.out"
  Current executable set to 'a.out' (x86_64).
  (lldb) run
  Process 30298 launched: 'example' (x86_64)
  Process 30298 stopped
  * thread #1, name = 'a.out', stop reason = breakpoint 1.1
      frame #0: 0x00000000004004b6 a.out`main at limitations_1.cpp:4
     1   	struct A{};
     2   	int main() {
     3   	  A a;
  -> 4   	}
  (lldb) cling print a
  False
  input_line_7:4:29: error: use of undeclared identifier 'A'
    std::add_lvalue_reference<A>::type a = *reinterpret_cast<std::remove_reference<A>::type*>((void*)0x00007fffffffe508);
                              ^
  input_line_7:4:33: error: no type named 'type' in the global namespace
    std::add_lvalue_reference<A>::type a = *reinterpret_cast<std::remove_reference<A>::type*>((void*)0x00007fffffffe508);
                                ~~^
  input_line_7:4:82: error: use of undeclared identifier 'A'
    std::add_lvalue_reference<A>::type a = *reinterpret_cast<std::remove_reference<A>::type*>((void*)0x00007fffffffe508);
                                                                                   ^
  input_line_7:4:86: error: expected '>'
    std::add_lvalue_reference<A>::type a = *reinterpret_cast<std::remove_reference<A>::type*>((void*)0x00007fffffffe508);
                                                                                       ^
                                                                                       >
  input_line_7:4:59: note: to match this '<'
    std::add_lvalue_reference<A>::type a = *reinterpret_cast<std::remove_reference<A>::type*>((void*)0x00007fffffffe508);
                                                            ^
  input_line_7:8:49: error: no type named 'print' in the global namespace
    Defrustrator::ValuePrinter<decltype(result)>::print(result); }
                                                ~~^
  Compilation failed
  (lldb)
  ```

# Troubleshooting

## `Error: target needs to be linked with libdl (add -ldl to compiler invocation)`

As the plugin loads the cling library into the debugged executable dynamically your executable has to be linked with `libdl`. In most cases appending `-ldl` to the compiler invocation is sufficient. Some versions of GCC though only link with a library if it is used in some sense. To force linking nonetheless alternatively add `-Wl,--whole-archive -ldl` to the invocation. The corresponding cmake command reads

```
SET(DL_LIBS_FORCE_LINK -Wl,--whole-archive ${CMAKE_DL_LIBS} -Wl,--no-whole-archive)
target_link_libraries(my_target ${DL_LIBS_FORCE_LINK})
```
