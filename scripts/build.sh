#!/bin/bash
# 快速构建脚本

echo "🚀 GraphMeeting 快速构建"

# 1. 仅构建 Rust（release 已缓存）
echo "🔨 检查 Rust 构建..."
cd rust
if [ ! -f target/release/libgraphmeeting_core.dylib ]; then
    cargo build --release
fi
cd ..

# 2. 运行 Flutter（debug 模式更快）
echo "🏃 启动 Flutter..."
flutter run -d macos --hot
