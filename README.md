# 🚀 Home Assistant CLI Rename Entities Script

This script allows you to rename entities in your Home Assistant setup using
the command line interface.

## 📚 Table of Contents

- [Installation](#-installation)
- [Usage](#-usage)
- [Custom Format Variables](#-custom-format-variables)
- [Examples](#-examples)
- [License](#-license)


## 🎉 Installation

To use this script, you need to have the [Home Assistant CLI](https://github.com/home-assistant-ecosystem/home-assistant-cli) installed on your system.

```bash
# pipx
pipx install homeassistant-cli

# regular pip
pip install --user homeassistant-cli
```

Then, download the `hass-cli-rename-entites.sh` script and make it executable:

```bash
chmod +x hass-cli-rename-entites.sh
```

## 💡 Usage

You can use the script with various options:

```bash
./hass-cli-rename-entites.sh [options]
```

Options:

- `-h, --help`: Display this help message
- `-D, --debug`: Enable debug mode
- `-k, --dry-run, --dryrun`: Enable dry run mode
- `-i, --integration <integration>`: Filter by integration
- `-m, --manufacturer <manufacturer>`: Filter by manufacturer
- `--only-named, --named-only`: Only consider named devices
- `--device-filter, --df, -f <filter>`: Filter devices by a custom string
- `--entity-filter, --ef, -e <filter>`: Filter entities by a custom string
- `-F, --format <format>`: Specify a custom name format
- `--strip-purpose, --sp <string>`: Strip a custom string from the entity's purpose
- `-p, --prefix <prefix>`: Specify a custom prefix

> [!NOTE]
> To inspect what the exact manufacturer or integration values are for your
> specific devices the easiest way is to run:
>
> ```shell
> hass-cli -o yaml device list
> ```

## 📝 Custom Format Variables

When specifying a custom format using the `-F` or `--format` flag, you can use
several variables that will be replaced by their respective values.
Here is a list of these variables:

- `${ENTITY_TYPE}`: The type of the entity (e.g., `light`, `switch`, `sensor`, etc.).
- `${INTEGRATION}`: The integration to which the entity belongs (e.g., `hue`, `homekit`, etc.).
- `${SLUG_DEVICE_NAME}`: The "slugified" version of the device name. This is a URL-friendly version of the name where spaces are replaced with underscores and special characters are removed.
- `${SLUG_OG_NAME_PURPOSE}`: The "slugified" version of the original name of the entity, with the device name removed. This typically leaves the purpose or role of the entity (e.g., `temperature`, `motion`, etc.).
- `${SLUG_ENTITY_FRIENDLY_NAME}`: The "slugified" version of the entity's friendly name. This is the name that you see in the Home Assistant UI.
- `${SLUG_OG_DEVICE_NAME}`: The "slugified" version of the original device name.
- `${SLUG_OG_NAME}`: The "slugified" version of the original name of the entity.
- `${SLUG_OG_NAME_LAST_WORD}`: The "slugified" version of the last word in the original name.
- `${SLUG_PREFIX}`: The "slugified" version of the prefix provided using the `-p` or `--prefix` flag.
- `${SLUG_PLATFORM}`: The "slugified" version of the platform to which the entity belongs.

The default format is the following:

```bash
${ENTITY_TYPE,,}.${SLUG_PREFIX}${SLUG_PLATFORM}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}
```

> [!NOTE]
> Remember that "slugification" is a process that transforms a string into a
> URL-friendly format by replacing spaces with underscores,
> converting all letters to lowercase, and removing special characters.
> It helps avoiding to attempt to set invalid entity id names.

> [!NOTE]
> The format value gets passed through `eval`, so you can just provide arbitrary
> code (sed/awk for example - see [below for an example](#rename-shelly-devices)).

## 🎈 Examples

Here are some examples showing how to use the script:

### Only Rename Named Devices

To only rename devices that have a name:

```bash
./hass-cli-rename-entites.sh --dry-run --named-only
```

### Filter by Integration and Specify Custom Format

To only rename entities from a specific integration and specify a custom format:

```bash
./hass-cli-rename-entites.sh --dry-run \
  --named-only \
  -i bluetooth \
  --format '${ENTITY_TYPE}.ble_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}' \
  --strip-purpose ble
```

### Filter by Manufacturer

To only rename entities from a specific manufacturer:

```bash
./hass-cli-rename-entites.sh --dry-run -m switchbot
```

### Filter by Integration and Device

To only rename entities from a specific integration and device:

```bash
./hass-cli-rename-entites.sh --dry-run \
  -i hue \
  --device-filter 'motion' \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
```

### Filter by Integration and Entity Type

To only rename entities from a specific integration and entity type:

```bash
./hass-cli-rename-entites.sh --dry-run \
  -i hue \
  --device-filter 'light' \
  --entity-filter "^light." \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}'
```

### Filter by Integration and Entity Type with Negative Lookahead

To only rename entities from a specific integration and entity type (not starting with "light."):

```bash
./hass-cli-rename-entites.sh --dry-run \
  -i hue \
  --device-filter 'light' \
  --entity-filter '^(?!light\.)' \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
```

### Filter by Integration and Entity Type (Excluding Light)

To only rename entities from a specific integration and entity type (excluding "light."):

```bash
./hass-cli-rename-entites.sh --dry-run \
  -i hue \
  --entity-filter '^(?!light\.)' \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
```

### Rename HomeKit Devices (Except Presence Sensors)

To rename HomeKit devices (excluding presence sensors):

```bash
./hass-cli-rename-entites.sh --dry-run \
  -i homekit \
  --device-filter '^(?!.+ presence sensor)' \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
```

### Rename HomeKit Presence Sensors

To rename HomeKit presence sensors:

```bash
./hass-cli-rename-entites.sh --dry-run \
  -i homekit \
  --device-filter '.+ presence sensor' \
  --entity-filter "^binary_sensor\..+" \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_ENTITY_FRIENDLY_NAME//presence_/}'
```

### Rename Shelly Devices

To rename Shelly devices:

```bash
./hass-cli-rename-entites.sh --dry-run \
  -m Shelly \
  --format '${ENTITY_TYPE}.shelly_${SLUG_DEVICE_NAME}$(sed -r "s/^(.+)/_\1/" <<< "${SLUG_OG_NAME_PURPOSE}")'
```

### Rename Yeelight Devices

To rename Yeelight devices:

```bash
hass-cli-rename-entites.sh --dry-run \
  -i yeelight \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}'
```

### Rename ZHA Devices

To rename ZHA devices:

```bash
hass-cli-rename-entites.sh --dry-run \
  --named-only \
  -i zha \
  --format '${ENTITY_TYPE}.${INTEGRATION}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'
```

## 📜 License

This project is licensed under the [GPL-3.0 License](./LICENSE).
