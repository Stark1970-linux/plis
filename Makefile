# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026 команда S.T.A.R.K.

.PHONY: apk clean icons license

apk:
	./build.sh

clean:
	./build.sh --clean

# Пересоздать значок приложения (нужен Python и Pillow)
icons:
	python3 tools/gen_icons.py

# Скачать официальный текст GPL v2 в файл COPYING
license:
	./tools/fetch-license.sh
