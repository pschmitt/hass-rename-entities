#!/usr/bin/env bash

# shellcheck disable=SC2016

rename_bluetooth() {
  ./hass-rename-entites.sh \
    --named-only \
    -i bluetooth \
    --format '${ENTITY_TYPE}.ble_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}' \
    --strip-purpose ble
}

rename_switchbot() {
  ./hass-rename-entites.sh \
    -m switchbot
}

rename_hue() {
  ./hass-rename-entites.sh \
    -i hue \
    --device-filter 'motion' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
  # Only lights themselves
  ./hass-rename-entites.sh \
    -i hue \
    --device-filter 'light' \
    --entity-filter "^light." \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}'
  # Other light device entities
  ./hass-rename-entites.sh \
    -i hue \
    --device-filter 'light' \
    --entity-filter '^(?!light\.)' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
  # Scenes, switch entities etc.
  ./hass-rename-entites.sh \
    -i hue \
    --entity-filter '^(?!light\.)' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
}

rename_homekit() {
  # Rename homekit devices (except presence sensors)
  ./hass-rename-entites.sh \
    -i homekit \
    --device-filter '^(?!.+ presence sensor)' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
  # Presence sensors
  ./hass-rename-entites.sh \
    -i homekit \
    --device-filter '.+ presence sensor' \
    --entity-filter "^binary_sensor\..+" \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_ENTITY_FRIENDLY_NAME//presence_/}'
}

rename_shelly() {
  ./hass-rename-entites.sh \
    -m Shelly \
    --format '${ENTITY_TYPE}.shelly_${SLUG_DEVICE_NAME}$(sed -r "s/^(.+)/_\1/" <<< "${SLUG_OG_NAME_PURPOSE}")'
}

rename_tado() {
  ./hass-rename-entites.sh \
    -i tado
}

rename_withings() {
  ./hass-rename-entites.sh \
    -m Withings \
    --format '${ENTITY_TYPE}.${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
}

rename_yeelight() {
  ./hass-rename-entites.sh \
    -i yeelight \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}'
}

rename_zha() {
  ./hass-rename-entites.sh \
    --named-only \
    -i zha \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  cd "$(cd "$(dirname "$0")" >/dev/null 2>&1; pwd -P)" || exit 9

  export NO_RESTART=1
  export PATCH_CONFIG_FILES=1

  rename_bluetooth
  rename_switchbot
  rename_homekit
  rename_hue
  rename_shelly
  rename_tado
  rename_yeelight
  rename_zha

  source ./hass-rename-entites.sh
  restart_hass
  watchman_report
fi
