#!/bin/bash

# Скрипт для сборки библиотеки для всех архитектур

set -e

echo "Сборка библиотеки lmdbx для всех архитектур..."
echo ""

# Очистка предыдущих сборок
rm -rf zig-out zig-cache

# Сборка всех целей
zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseFast
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseFast
zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseFast

echo ""
echo "================================================"
echo "✅ Все библиотеки успешно собраны!"
echo "================================================"
echo ""
ls -lh zig-out/lib/

exit 0
