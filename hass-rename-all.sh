#!/usr/bin/env bash

# shellcheck disable=SC2016

rename_bluetooth() {
  ./hass-rename-entities.sh \
    --named-only \
    -i bluetooth \
    --format '${ENTITY_TYPE}.ble_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}' \
    --strip-purpose ble
}

rename_elgato() {
  ./hass-rename-entities.sh -i elgato --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
}

rename_hue() {
  ./hass-rename-entities.sh \
    -i hue \
    --device-filter 'motion' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
  # Only lights themselves
  ./hass-rename-entities.sh \
    -i hue \
    --device-filter 'light' \
    --entity-filter "^light." \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}'
  # Other light device entities
  ./hass-rename-entities.sh \
    -i hue \
    --device-filter 'light' \
    --entity-filter '^(?!light\.)' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
  # Scenes, switch entities etc.
  ./hass-rename-entities.sh \
    -i hue \
    --entity-filter '^(?!light\.)' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
}

rename_homekit() {
  # Rename homekit devices (except presence sensors)
  ./hass-rename-entities.sh \
    -i homekit \
    --device-filter '^(?!Presence Sensor .+)' \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
  # Presence sensors
  ./hass-rename-entities.sh \
    -i homekit \
    --device-filter 'Presence Sensor .+' \
    --entity-filter "^binary_sensor\..+" \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_ENTITY_FRIENDLY_NAME//presence_/}'
}

rename_shelly() {
  ./hass-rename-entities.sh \
    -m Shelly \
    --format '${ENTITY_TYPE}.shelly_${SLUG_DEVICE_NAME}$(sed -r "s/^(.+)/_\1/" <<< "${SLUG_OG_NAME_PURPOSE}")'
}

rename_switchbot() {
  ./hass-rename-entities.sh \
    -m switchbot
}

rename_tado() {
  ./hass-rename-entities.sh \
    -i tado
}

rename_withings() {
  ./hass-rename-entities.sh \
    -i withings \
    --format '${ENTITY_TYPE}.withings_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
}

rename_yeelight() {
  ./hass-rename-entities.sh \
    -i yeelight \
    --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}'
}

rename_zha() {
  ./hass-rename-entities.sh \
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
  rename_elgato
  rename_homekit
  rename_hue
  rename_shelly
  rename_switchbot
  rename_tado
  rename_withings
  rename_yeelight
  rename_zha

  source ./hass-rename-entities.sh
  restart_hass
  watchman_report
fi
