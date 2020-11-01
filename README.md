# luaprof

## 说明
Lua 性能检测工具

**功能**
- 检测每个函数的实际执行时间
- 检测每个函数的执行次数
- 到函数调用关系导出为图像


## 效果图

**终端打印图**

括号中第一列为函数调用次数，第二列为函数调用占总函数调用的比例，第三列为函数总的实际执行时间

![image](image/终端打印图.jpg)

**graphviz调用关系导出图(未开启剪枝)**

![image](image/调用关系导出图1.jpg)

**graphviz调用关系导出图(开启剪枝，不显示所有调用次数少于2的函数节点，注意：当前设计方案对于递归调用无法消除)**

![image](image/调用关系导出图2.jpg)


## 安装
要使用这个库，需要将 `timer.c` 编译成动态库，`timer.c` 需要用到 Lua 的头文件，如果系统中没有的话，需要手动安装

在 Ubuntu 系统中，安装方式为
```
sudo apt-get install lua5.3-dev
```

安装完头文件后，执行 `sh build.sh` 即可编译出 `timerlib.so` 动态库



## 参考
> [利用debug库实现对lua的性能分析](https://tboox.org/cn/2017/01/12/lua-profiler/)
