#!/bin/bash

clear
echo -e "\033[0;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;32m⚙️  Скрипт для настройки BBR + FQ для оптимизации TCP\033[0m"
echo -e "📶 Данная настройка улучшает скорость и стабильность TCP-соединений (особенно подходит для сайтов, VPN и SSH)."
echo -e "\033[0;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo

# Проверка root
if [[ $EUID -ne 0 ]]; then
  echo -e "\033[1;31m🚫 Пожалуйста, запусти скрипт с правами root (sudo)\033[0m"
  exit 1
fi

# Проверка поддержки BBR через modinfo
if ! modinfo tcp_bbr &>/dev/null; then
  echo -e "\033[1;31m❌ Ядро не содержит модуль BBR (tcp_bbr).\033[0m"
  echo -e "🛠 Установи полноценное ядро: \033[1;33msudo apt install linux-image-amd64\033[0m"
  echo -e "🔁 И затем перезагрузи систему: \033[1;33msudo reboot\033[0m"
  exit 1
fi

# Проверка текущего алгоритма
CURRENT_ALGO=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
if [[ "$CURRENT_ALGO" == "bbr" ]]; then
  echo -e "✅ У вас уже включён BBR: \033[1;32m$CURRENT_ALGO\033[0m"
  exit 0
fi

echo -e "🚀 Текущий алгоритм: \033[1;33m$CURRENT_ALGO\033[0m"
echo -e "\033[1;34m➡️ Начать установку BBR + FQ? (y/n): \033[0m"
read -r confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "❌ Установка отменена."
  exit 0
fi

# Пробуем загрузить модуль
if ! lsmod | grep -q bbr; then
  modprobe tcp_bbr && echo "✅ Модуль tcp_bbr загружен"
else
  echo "✅ Модуль tcp_bbr уже активен"
fi

# Бэкап sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.bak_$(date +%s)
echo "🗄️ Резервная копия sysctl.conf создана"

# Добавление настроек, если ещё не добавлены
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
  {
    echo ""
    echo "# --- BBR + FQ Optimization ---"
    echo "net.core.default_qdisc=fq"
    echo "net.ipv4.tcp_congestion_control=bbr"
    echo "net.core.rmem_default=262144"
    echo "net.core.rmem_max=4194304"
    echo "net.core.wmem_default=262144"
    echo "net.core.wmem_max=4194304"
  } >> /etc/sysctl.conf
fi

# Применяем настройки
echo "🔄 Применяем настройки..."
sysctl -p

# Проверка результата
NEW_ALGO=$(sysctl -n net.ipv4.tcp_congestion_control)
if [[ "$NEW_ALGO" == "bbr" ]]; then
  echo -e "\033[1;32m✅ BBR был успешно включён.\033[0m"
else
  echo -e "\033[1;31m⚠️  Не удалось включить BBR. Текущий алгоритм: $NEW_ALGO\033[0m"
fi

exit 0
