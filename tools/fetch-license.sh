#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026 команда S.T.A.R.K.
#
# Скачивает официальный текст GNU GPL версии 2 с сайта GNU в файл COPYING.
# Текст лицензии нельзя менять, поэтому берём его у первоисточника, а не набираем вручную.
set -eu
cd "$(dirname "$0")/.."
curl -fsSL https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt -o COPYING
echo "Готово: COPYING ($(wc -c < COPYING) байт)"
