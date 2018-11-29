#include <iostream>
#include <Eigen/Dense>

int main() {
  // A = [ 1 0 0;
  //       0 2 0;
  //       0 0 3 ]
  Eigen::Matrix<double, 3, 3> A;
  A << 1, 0, 0,
       0, 2, 0,
       0, 0, 3;
  // x = [1 1 1]
  Eigen::Matrix<double, 3, 1> x;
  x.setConstant(1);

  // compute A*x
  //  store result in vector b1
  Eigen::Matrix<double, 3, 1> b1 = A * x;
  // store result in variable of type returned by expression A*x
  auto b2 = A * x;

  // compute b1^T b2
  auto c = b1.transpose() * b2;

  return 0;
}
