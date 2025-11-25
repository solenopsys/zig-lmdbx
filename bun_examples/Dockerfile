FROM oven/bun:1.3-alpine

WORKDIR /app

# Копируем musl библиотеку для Alpine x86_64
COPY zig-out/lib/liblmdbx-x86_64-musl.so /app/libs/

# Копируем TypeScript файлы
COPY bun_examples/lmdbx.ts /app/
COPY bun_examples/test.ts /app/

# Устанавливаем переменную окружения для поиска библиотек
ENV BIN_LIBS_PATH=/app/libs

# Запускаем простой тест
CMD ["bun", "run", "test.ts"]