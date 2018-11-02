#include <type_traits>
#include <typeinfo>
#include <cxxabi.h>
#include <memory>
#include <string>
#include <cstdlib>

#ifndef DEFRUSTRATOR_VALUE_PRINTER_HPP
#define DEFRUSTRATOR_VALUE_PRINTER_HPP

namespace Defrustrator {

namespace Utils {

template <typename T, typename = void>
struct InsertionOperatorExists {
    static constexpr bool value = false;
};

template <typename T>
struct InsertionOperatorExists<T, typename std::enable_if<std::is_same<
        decltype(std::declval<std::ostream&>() << std::declval<T>()), std::ostream&>::value>::type> {
    static constexpr bool value = true;
};

// taken from https://stackoverflow.com/questions/81870/is-it-possible-to-print-a-variables-type-in-standard-c
template <class T> std::string type_name() {
    typedef typename std::remove_reference<T>::type TR;
    std::unique_ptr<char, void(*)(void*)> own(abi::__cxa_demangle(typeid(TR).name(), nullptr,
                                                                  nullptr, nullptr), std::free);
    std::string r = own != nullptr ? own.get() : typeid(TR).name();
    if (std::is_const<TR>::value)
        r += " const";
    if (std::is_volatile<TR>::value)
        r += " volatile";
    if (std::is_lvalue_reference<T>::value)
        r += "&";
    else if (std::is_rvalue_reference<T>::value)
        r += "&&";
    return r;
}

}

template <typename T, typename = void>
struct ValuePrinter {
    static void print(const T& val) {
        std::cout << "(" << Utils::type_name<T>() << ") @" << &val << std::endl;
    }
};

template <typename T>
struct ValuePrinter<T, typename std::enable_if<Utils::InsertionOperatorExists<T>::value>::type> {
    static void print(const T& val) {
        std::cout << val << std::endl;
    }
};

};

#endif