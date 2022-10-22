#!/usr/bin/env sh

set -euf

if [ "${HELM_DEBUG:-}" = "1" ] || [ "${HELM_DEBUG:-}" = "true" ]; then
    set -x
fi

fragments="${4##kubectl://}"

ignore_errors=false

namespace="$(echo "${fragments}" | cut -d/ -f1)"
kind="$(echo "${fragments}" | cut -d/ -f2)"
name="$(echo "${fragments}" | cut -d/ -f3)"
output="$(echo "${fragments}" | cut -d/ -f4-)"

if [ "${namespace##\?}" != "${namespace}" ]; then
  namespace="${namespace##\?}"
  ignore_errors=true
fi

if [ "${ignore_errors}" = "false" ]; then
  exec "${HELM_KUBECTL_KUBECTL_PATH:-kubectl}" get ${namespace:+-n "${namespace}"} "${kind}" "${name}" -o "${output:-json}"
else
  if ! "${HELM_KUBECTL_KUBECTL_PATH:-kubectl}" get ${namespace:+-n "${namespace}"} "${kind}" "${name}" -o "${output:-json}" 2>/dev/null; then
    :
  fi
fi
