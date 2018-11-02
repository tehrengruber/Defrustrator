#include <Eigen/Dense>
#include <iostream>

int main() {
  int a = 1;
  void const * b = nullptr; // pointer to const
  void * const c = nullptr; // const pointer
  void const * const d = nullptr; // const pointer to const
  void const * const * volatile const * e = nullptr;
//  void(*bla)(Eigen::VectorXd*) = nullptr;
//  const Eigen::VectorXd* einlangername = new Eigen::VectorXd(3, 1);
  Eigen::VectorXd v2(3, 1);
  v2.setConstant(1);
}
