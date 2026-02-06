#!/bin/bash
# GraphMeeting 项目初始化脚本

set -e

echo "🚀 初始化 GraphMeeting 项目..."
echo ""

# 检查环境
echo "📋 检查环境..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装"
    exit 1
fi

if ! command -v cargo &> /dev/null; then
    echo "❌ Rust/Cargo 未安装"
    exit 1
fi

echo "  ✓ Flutter: $(flutter --version | head -1)"
echo "  ✓ Cargo: $(cargo --version)"
echo ""

# 安装 Flutter 依赖
echo "📦 安装 Flutter 依赖..."
flutter pub get
echo ""

# 安装 Rust 依赖
echo "📦 安装 Rust 依赖..."
cd rust
cargo fetch
echo ""

# 构建 Rust 核心库
echo "🔨 构建 Rust 核心库 (release)..."
cargo build --release
cd ..
echo ""

# 验证
echo "🔍 验证项目..."
flutter analyze --suppress-analytics 2>&1 | grep -E "error" && echo "❌ 发现错误" || echo "  ✓ 代码分析通过"
echo ""

echo "✅ GraphMeeting 项目初始化完成!"
echo ""
echo "🎯 运行应用:"
echo "   flutter run"
echo ""
echo "📚 更多信息请查看 AGENTS.md"
