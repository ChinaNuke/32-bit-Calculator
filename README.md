# 32-bit-Calculator

基于8086 CPU和8255A等硬件的32位计算器，完成于2019年12月，适用于`SUN ES8086实验箱`。实现了32位的加、减、乘运算，使用4×4的键盘输入，将输入内容和计算结果在8个七段数码管上，并实现了输入内容溢出、计算结果溢出、中间计算结果溢出等异常情况的处理和错误码显示，计算的过程使用算符优先算法。

程序总体上分为输出显示、输入和内容处理以及核心算法三大模块，具有低耦合的特点。

需要注意的是，这个程序存在一个没有改正的小bug，但由于时间久远我不记得是啥了。程序中计算算法部分写的非常糟糕，如果你恰好要用到这个程序，请忽略计算算法部分，建议将输入表达式转换成逆波兰式再进行计算。

程序具体细节以后再补充，先留坑。