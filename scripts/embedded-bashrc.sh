
# ============================================
# 嵌入式开发环境配置
# ============================================

# 工具链别名
alias arm-gcc='arm-none-eabi-gcc'
alias arm-g++='arm-none-eabi-g++'
alias arm-objdump='arm-none-eabi-objdump'
alias arm-size='arm-none-eabi-size'
alias arm-gdb='arm-none-eabi-gdb'
alias arm-nm='arm-none-eabi-nm'
alias arm-readelf='arm-none-eabi-readelf'

# 代码质量工具别名
alias cf='clang-format'
alias ct='clang-tidy'
alias cppc='cppcheck --enable=all --suppress=missingIncludeSystem'

# 覆盖率别名
alias cov='gcovr -r . --html --html-details -o coverage.html'

# 常用目录
export WORKSPACE=/workspace
export TOOLCHAINS=/opt/toolchains
export TEST_FRAMEWORKS=/opt/test-frameworks

# 提示符
export PS1='\[\e[32m\][embedded-dev]\[\e[0m\] \w \$ '

# 工具路径
export PATH="/opt/toolchains/arm-none-eabi/bin:$PATH"
export PATH="/root/.cargo/bin:$PATH"

# 欢迎信息
echo "=========================================="
echo "  Embedded Dev Environment v2.0"
echo "=========================================="
echo "可用工具:"
echo "  编译: arm-gcc, clang, cmake, meson"
echo "  检查: clang-tidy, cppcheck, valgrind"
echo "  测试: gtest, cmocka, unity"
echo "  调试: gdb, openocd, qemu"
echo "  文档: doxygen, sphinx"
echo "  AI:   claude"
echo "=========================================="
