#!/usr/bin/env sh

set -euf

if [ "${HELM_DEBUG:-}" = "1" ] || [ "${HELM_DEBUG:-}" = "true" ]; then
    set -x
fi

arg=$4

if [[ ! "${arg}" =~ ^kubectl://.*$ ]]; then
	echo "Protocol unknown in '${arg}'." 1>&2;
	exit 1;
fi

fragments="${arg##kubectl://}"

ignore_errors=false

namespace="$(printf '%s' "${fragments}" | cut -d/ -f1)"
kind="$(printf '%s' "${fragments}" | cut -d/ -f2)"
name="$(printf '%s' "${fragments}" | cut -d/ -f3)"
labels="$(printf '%s' "${fragments}" | cut -d/ -f4)"
output="$(printf '%s' "${fragments}" | cut -d/ -f5-)"

label_list="$(printf '%s' "${labels}" | cut -d'|' -f1)"
label_IFS="$(printf '%s' "${labels}" | cut -d'|' -f2)"
label_method="$(printf '%s' "${labels}" | cut -d'|' -f3-)"
label_method_command="$(printf '%s' "${label_method}" | cut -d? -f1)"
label_method_args="$(printf '%s' "${label_method}" | cut -d? -f2-)"

# at least \n, \t by default
IFS=$'\n\t'${label_IFS}

if [ "${namespace##\?}" != "${namespace}" ]; then
	namespace="${namespace##\?}"
	ignore_errors=true
fi



set +e
result=$( "${HELM_KUBECTL_KUBECTL_PATH:-kubectl}" get ${namespace:+-n "${namespace}"} "${kind}" ${label_list:+-l "${label_list}"} ${name} -o "${output:-json}" 2>&1 )
code=$?;
set -e

if [[ "$code" == 0 ]]; then
	case $label_method_command in
	"" | all)
		printf '%s' $result
		;;
	same)
		items=()
		for item in $result; do
			items+=($item)
		done
		if (( ${#items[@]} )); then
			first_item=${items[1]}
			for item in "${items[@]}"; do
				if [ "${item}" != "${first_item}" ]; then
					if [ "${ignore_errors}" = "true" ]; then exit 0;
					else
						echo "The output does not contain only same items. Please check the inputted output format '${output}' as well as the use of of label method command '${label_method_command}'. Kubectl output gives: ${result}" 1>&2;
						exit 1;
					fi
				fi
			done
			printf '%s' "${first_item}"
		else
			printf '%s' $result
		fi
		;;
	get)
		items=()
		for item in $result; do
			items+=($item)
		done
		if (( $label_method_args >=0  )) && (( $label_method_args < ${#items[@]} )); then
			printf '%s' "${items[$label_method_args]}"
		elif [ "${ignore_errors}" = "true" ]; then exit 0;
		else
			echo "Index ${label_method_args} out of range for the output list length ${#items[@]}. Please check your output '${output}'." 1>&2;
			exit 1;
		fi
		;;
	*)
		echo "An error occured when using helm plugin 'kubectl' on fragment '${arg}'. Unrecognized method '${label_method_command}'. Must be one of the following: ['', 'all', 'get', 'same']" 1>&2;
		exit 1;
	esac
elif [ "${ignore_errors}" = "true" ]; then exit 0;
else
	echo "An error occured when using helm plugin 'kubectl' on fragment '${arg}'. Please check: ${result}" 1>&2;
	exit 1;
fi
