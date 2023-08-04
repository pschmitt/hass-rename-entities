#!/usr/bin/env bash

set -eo pipefail

# shellcheck disable=2016
DEFAULT_FORMAT='${ENTITY_TYPE,,}.${SLUG_PREFIX}${SLUG_PLATFORM}_${SLUG_DEVICE_NAME}_${SLUG_OG_NAME_PURPOSE}'

usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h, --help                           Display this help message"
  echo "  -D, --debug                          Enable debug mode"
  echo "  -k, --dry-run, --dryrun              Enable dry run mode"
  echo "  -n, --no-restart                     Do not restart Home Assistant after renaming the entities"
  echo "  --watchman                           Generate a new watchman report after renaming the entities"
  echo "  -P, --patch-config-files             Patch config files after renaming the entities (sed and replace on all files in ${HASS_CONFIG_DIR:-/config})"
  echo "  -i, --integration <integration>      Filter by integration"
  echo "  -m, --manufacturer <manufacturer>    Filter by manufacturer"
  echo "  --only-named, --named-only           Only consider named devices"
  echo "  --device-filter, --df, -f <filter>   Filter devices by a custom string"
  echo "  --entity-filter, --ef, -e <filter>   Filter entities by a custom string"
  echo "  -F, --format <format>                Specify a custom name format"
  echo "                                       Default format:"
  echo "                                       ${DEFAULT_FORMAT}"
  echo "  --strip-purpose, --sp <string>       Strip a custom string from the entity's purpose"
  echo "  -p, --prefix <prefix>                Specify a custom prefix"
}


echo_debug() {
  [[ -n "$DEBUG" ]] || return 0
  echo -e "\e[35m🐞 [DEBUG] ${*}\e[0m" >&2
}

echo_info() {
  echo -e "\e[34mℹ️  [INFO] ${*}\e[0m" >&2
}

echo_success() {
  echo -e "\e[32m✅ [SUCCESS] ${*}\e[0m" >&2
}

echo_warning() {
  echo -e "\e[33m⚠️  [WARNING] ${*}\e[0m" >&2
}

echo_dryrun() {
  local -a args=()
  case "$1" in
    -n)
      args+=(-n)
      shift
      ;;
  esac

  echo "${args[@]}" -e "\e[95m🦺 [DRY_RUN] ${*}\e[0m" >&2
}

transliterate() {
  # TODO Transliteration with iconv
  # Sadly //TRANSLIT is not supported by musl
  # echo "Früchte" | iconv -f utf-8 -t ascii//TRANSLIT
  sed 's/ü/ue/g; s/Ü/Ue/g; s/ö/oe/g; s/Ö/Oe/g; s/ä/ae/g; s/Ä/Ae/g; s/ß/ss/g'
}

slugify() {
  local n="$1"

  if [[ -z "$n" ]]
  then
    echo_warning "${FUNCNAME[0]}: Empty input"
    return 1
  fi

  # Replace spaces, slashes, dots and dashes with underscores
  n=${n// /_}
  n=${n////_}
  n=${n//-/_}
  n=${n//./_}
  # Remove [:;()]
  n=${n//(/}
  n=${n//)/}
  n=${n//:/}
  n=${n//;/}

  if [[ -z "$n" ]]
  then
    echo_warning "$0: Empty output"
    return 1
  fi

  transliterate <<< "${n,,}"
}

restart_hass() {
  echo_info "🏁 Restarting Home Assistant"

  if command -v ha &>/dev/null
  then
    ha core restart
  else
    ssh hv "source /etc/profile.d/homeassistant.sh; ha core restart"
  fi
}

watchman_report() {
  echo_info "Requesting a new watchman report"
  hass-cli service call watchman.report
}

find_matching_config_files() {
  local search="$1"
  local -a matching_files

  # NOTE To support busybox grep here we can't use the --files-with-matches flag
  mapfile -t matching_files < <(
    grep -l -R "$search" ./*.yaml ./config.d/*.yaml .storage/lovelace.* | \
      grep -v .renamed.
  )

  if [[ -z "${matching_files[*]}" ]]
  then
    return 1
  fi

  printf '%s\n' "${matching_files[@]}"
}

patch_config() {
  local old="$1" new="$2"

  if [[ -z "$old" ]]
  then
    echo "OLD entity_id is not set!" >&2
    return 1
  fi

  if [[ -z "$new" ]]
  then
    echo "NEW entity_id is not set!" >&2
    return 1
  fi

  # Go to config dir
  cd "$HASS_CONFIG_DIR" &>/dev/null || cd /mnt/hass-*

  local matching_files file
  mapfile -t matching_files < <(
    grep --files-with-matches -R "$old" ./*.yaml ./config.d/*.yaml .storage/lovelace.* | \
      grep -v .renamed.
  )

  for file in "${matching_files[@]}"
  do
    echo "Patching file $file (s/${old}/${new}/g)"
    sed -i".renamed.$(date -Iseconds).bak" "s/${old}/${new}/g" "$file"

    # Delete backup files if there was no change
    # if ! diff "${file}" "${file}.renamed.bak" &>/dev/null
    # then
    #   rm -f "${file}.renamed.bak"
    # fi
  done
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  RC=0
  FAILED_RENAMES=()
  HASS_CONFIG_DIR="${HASS_CONFIG_DIR:-/config}"

  while [[ -n "$*" ]]
  do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -D|--debug)
        DEBUG=1
        shift
        ;;
      -k|--dry-run|--dryrun)
        DRY_RUN=1
        shift
        ;;
      -n|--no-restart)
        NO_RESTART=1
        shift
        ;;
      --watchman)
        WATCHMAN_REPORT=1
        shift
        ;;
      -P|--patch-config-files)
        PATCH_CONFIG_FILES=1
        shift
        ;;
      -i|--integration)
        INTEGRATION="$2"
        shift 2
        ;;
      -m|--manufacturer)
        MANUFACTURER="$2"
        shift 2
        ;;
      --only-named|--named-only)
        NAMED_ONLY=1
        shift
        ;;
      --device-filter|--df|-f)
        DEVICE_FILTER="$2"
        shift 2
        ;;
      --entity-filter|--ef|-e)
        ENTITY_ID_FILTER="$2"
        shift 2
        ;;
      -F|--format)
        NAME_FORMAT="$2"
        shift 2
        ;;
      --strip-purpose|--sp)
        STRIP_PURPOSE="$2"
        shift 2
        ;;
      -p|--prefix)
        SLUG_PREFIX="$(slugify "$2")"
        shift 2
        ;;
      *)
        {
          echo "Unknown option: $1"
          usage
        }>&2
        exit 2
        ;;
    esac
  done

  cd "$(cd "$(dirname "$0")" >/dev/null 2>&1; pwd -P)/.." || exit 9

  if [[ -z "$INTEGRATION" ]] && [[ -z "$MANUFACTURER" ]]
  then
    echo "Missing --integration or --manufacturer flags" >&2
    exit 2
  fi

  echo_info "Fetching devices and entity data"
  DEVICES="$(hass-cli -o yaml device list | yq -e --unwrapScalar 'sort_by(.name_by_user // .name)')"
  ENTITIES="$(hass-cli -o yaml entity list | yq -e --unwrapScalar 'sort_by(.entity_id)')"

  if [[ -n "$INTEGRATION" ]]
  then
    DEVICES="$(INTEGRATION=$INTEGRATION \
      yq -e '[.[] | select(.identifiers | contains([strenv(INTEGRATION)]))]' <<< "$DEVICES")"
  fi

  if [[ -n "$MANUFACTURER" ]]
  then
    DEVICES="$(MANUFACTURER=$MANUFACTURER \
      yq -e '[.[] | select(.manufacturer // "" | test(strenv(MANUFACTURER)))]' <<< "$DEVICES")"
  fi

  if [[ -n "$NAMED_ONLY" ]]
  then
    DEVICES="$(yq -e '[.[] | select(.name_by_user != "" and .name_by_user != null)]' <<< "$DEVICES")"
  fi

  mapfile -t DEVICE_IDS < <(yq '.[].id' <<< "$DEVICES")
  # echo "Matching devices"
  # for m in "${DEVICE_IDS[@]}"
  # do
  #   echo "$m"
  # done

  for DEVICE_ID in "${DEVICE_IDS[@]}"
  do
    DEVICE_DATA="$(DEVICE_ID="${DEVICE_ID}" yq -e '[.[] | select(.id == strenv(DEVICE_ID))][0]' <<< "$DEVICES")"
    # NOTE: Area ID is not always set
    # shellcheck disable=SC2034
    DEVICE_AREA_ID="$(yq --unwrapScalar '.area_id // ""' <<< "$DEVICE_DATA")"
    DEVICE_FRIENDLY_NAME="$(yq -e --unwrapScalar '.name_by_user // .name' <<< "$DEVICE_DATA")"
    OG_DEVICE_NAME="$(yq -e --unwrapScalar '.name' <<< "$DEVICE_DATA")"

    if [[ -n "$DEVICE_FILTER" ]]
    then
      if ! grep -iqP "$DEVICE_FILTER" <<< "$DEVICE_FRIENDLY_NAME"
      then
        echo_warning "Skipping device $DEVICE_FRIENDLY_NAME since it does not match \"$DEVICE_FILTER\""
        continue
      fi
    fi

    echo_info "\e[1m⚙️  Processing $DEVICE_FRIENDLY_NAME ($DEVICE_ID)"
    # FIXME It'll be safer to work with a YAML structure here, rather than
    # relying on read -r and space separation
    # OG NAME can be multiple words long and therefore needs to be the last
    # property in the list.
    mapfile -t DEVICE_ENTITIES < <(
      DEVICE_ID="$DEVICE_ID" yq '.[] | select(.device_id == strenv(DEVICE_ID)) | .entity_id' <<< "$ENTITIES"
    )

    for ENTITY_ID in "${DEVICE_ENTITIES[@]}"
    do
      ENTITY_DATA="$(ENTITY_ID="$ENTITY_ID" \
        yq -e --unwrapScalar '[.[] | select(.entity_id == strenv(ENTITY_ID))][0]' <<< "$ENTITIES")"

      PLATFORM="$(yq -e --unwrapScalar '.platform' <<< "$ENTITY_DATA")"
      OG_NAME="$(yq -e --unwrapScalar '.original_name' <<< "$ENTITY_DATA")"

      if [[ -n "$ENTITY_ID_FILTER" ]]
      then
        if ! grep -iqP "$ENTITY_ID_FILTER" <<< "$ENTITY_ID"
        then
          echo_warning "Skipping entity_id $ENTITY_ID since it does not match \"$ENTITY_ID_FILTER\""
          continue
        fi
      fi
      echo_info "Processing entity_id $ENTITY_ID (${DEVICE_FRIENDLY_NAME})"

      ENTITY_TYPE=${ENTITY_ID//\.*/}
      # shellcheck disable=SC2034
      ENTITY_FRIENDLY_NAME="$(yq --unwrapScalar '.name // ""' <<< "$ENTITY_DATA")"

      SLUG_DEVICE_NAME="$(slugify "$DEVICE_FRIENDLY_NAME"; true)"
      SLUG_OG_DEVICE_NAME="$(slugify "$OG_DEVICE_NAME"; true)"
      SLUG_OG_NAME="$(slugify "$OG_NAME")"
      SLUG_OG_NAME_LAST_WORD="$(slugify "${OG_NAME##* }")"
      AREA_ID="$(yq --unwrapScalar '.area_id // ""' <<< "$ENTITY_DATA")"
      # Default to device area id
      AREA_ID="${AREA_ID:-$DEVICE_AREA_ID}"
      # remove the device name from the original entity name and
      # trim leading and trailing whitespace with awk
      # https://unix.stackexchange.com/a/205854
      PURPOSE="$(awk '{$1=$1;print}' <<< "${OG_NAME//"${OG_DEVICE_NAME}"}"; true)"
      if [[ -n "$STRIP_PURPOSE" ]]
      then
        PURPOSE="$(awk '{$1=$1;print}' <<< "${PURPOSE//"${STRIP_PURPOSE}"}")"
      fi
      SLUG_OG_NAME_PURPOSE="$(slugify "$PURPOSE"; true)"
      SLUG_PLATFORM="$(slugify "${PLATFORM}")"
      # shellcheck disable=SC2034
      SLUG_ENTITY_FRIENDLY_NAME="$(slugify "${ENTITY_FRIENDLY_NAME}"; true)"

      echo_debug "OG_NAME: ${OG_NAME}"
      echo_debug "DEVICE_FRIENDLY_NAME: ${DEVICE_FRIENDLY_NAME}"
      echo_debug "SLUG_DEVICE_NAME: ${SLUG_DEVICE_NAME}"
      echo_debug "OG_DEVICE_NAME: ${OG_DEVICE_NAME}"
      echo_debug "PURPOSE: ${PURPOSE}"
      echo_debug "SLUG_OG_NAME_PURPOSE: ${SLUG_OG_NAME_PURPOSE}"

      if [[ -n "$NAME_FORMAT" ]]
      then
        # Customing naming
        NEW_ENTITY_ID="$(\
          TYPE=$ENTITY_TYPE \
          DEVICE_NAME=$SLUG_DEVICE_NAME \
          OG_NAME=$SLUG_OG_NAME \
          OG_DEVICE_NAME=$SLUG_OG_DEVICE_NAME \
          OG_NAME_LW=$SLUG_OG_NAME_LAST_WORD \
          PREFIX=$SLUG_PREFIX \
          eval echo "$NAME_FORMAT")"
      else
        # Default naming scheme
        NEW_ENTITY_ID="$(eval echo "$DEFAULT_FORMAT")"
      fi

      # Remove trailing _
      NEW_ENTITY_ID=${NEW_ENTITY_ID%_}

      # Check if the new entity ID is valid by:
      #   - checking if it is empty
      #   - checking that is is less than 255 chars long
      #   - it contains exactly one dot char
      #   - ensuring the sensor type is the same
      if [[ -z "$NEW_ENTITY_ID" ]] || \
         [[ "${#NEW_ENTITY_ID}" -ge 255 ]] || \
         [[ "$(awk -F"." '{print NF-1}' <<< "$NEW_ENTITY_ID")" -ne 1 ]] || \
         [[ "${NEW_ENTITY_ID//\.*/}" != "$ENTITY_TYPE" ]]
      then
        echo_warning "INVALID ENTITY_ID: $NEW_ENTITY_ID"
        RC=1
        FAILED_RENAMES+=("$ENTITY_ID -> $NEW_ENTITY_ID [Invalid entity ID]")
        continue
      fi

      if [[ "$ENTITY_ID" == "$NEW_ENTITY_ID" ]]
      then
        echo_success "Nothing to do for ${ENTITY_ID}"
        continue
      fi

      echo_info "📛 Rename \e[1m\e[93m${ENTITY_ID}\e[0m\e[34m to \e[1m\e[93m${NEW_ENTITY_ID}\e[0m\e[34m"

      if [[ -n "$DRY_RUN" ]]
      then
        echo_dryrun "hass-cli entity rename \"$ENTITY_ID\" \"$NEW_ENTITY_ID\""
        echo_dryrun "Run sed 's/${ENTITY_ID}/${NEW_ENTITY_ID}/g' on config directory"
        echo_dryrun -n "Config files matching old entity id: "
        if ! config_files_matches="$(find_matching_config_files "$ENTITY_ID")"
        then
          echo -e "\e[95mNONE!\e[0m"
        else
          echo
          echo -e "\e[95m$(awk '{ print "- " $0}' <<< "${config_files_matches}")\e[0m"
        fi
      else
        RES="$(hass-cli entity rename "$ENTITY_ID" "$NEW_ENTITY_ID")"
        if ! yq -e '.[0].success == true' <<< "$RES" &>/dev/null
        then
          {
            ERR_MSG="$(yq '.[0].error.message' <<< "$RES")"
            RC=1

            echo_warning "💣 Failed to rename entity"
            echo_warning "$RES"
            echo_warning "$ERR_MSG"

            FAILED_RENAMES+=("$ENTITY_ID -> $NEW_ENTITY_ID [$ERR_MSG]")
            continue
          } >&2
        fi

        echo_success "Renamed successfully."

        if [[ -n "$PATCH_CONFIG_FILES" ]]
        then
          echo_info "Patching config files..."
          patch_config "$ENTITY_ID" "$NEW_ENTITY_ID"
        fi
      fi
    done
  done

  if [[ -n "${FAILED_RENAMES[*]}" ]]
  then
    echo_warning "📖 Failed to rename:"
    for e in "${FAILED_RENAMES[@]}"
    do
      echo "  - ${e}"
    done
  fi

  if [[ -n "$DRY_RUN" ]]
  then
    echo_dryrun "🔁 Restart Home Assistant"
  else
    if [[ -z "$NO_RESTART" ]]
    then
      restart_hass
    fi
  fi

  if [[ -n "$WATCHMAN_REPORT" ]]
  then
    watchman_report
  fi

  exit "$RC"
fi
