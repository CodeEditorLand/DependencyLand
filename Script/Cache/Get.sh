#!/bin/bash

\echo "Process: Cache/Get.sh"
\printf "Arguments: %s\n" "$*"

# Contextless

Current=$(\cd -- "$(\dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [ $# -gt 0 ]; then
	if [ -f "$1" ]; then
		\mapfile -t Organization < <(jq -r '.[]' "$1" | \tr -d '\r')
	else
		\echo "Error: Organization file not found: $1"
		\exit 1
	fi

	if [ -f "$2" ]; then
		mapfile -t Omit < <(jq -r '.[]' "$2" | \tr -d '\r')
	else
		\echo "Error: Omit file not found: $2"
		\exit 1
	fi

	if [ -n "$3" ]; then
		Service=$3
	else
		\echo "Error: No Service specificed: $3"
		\exit 1
	fi
fi

Repository=()

for Organization in "${Organization[@]}"; do
	for ((Page = 1; Page <= 20; Page++)); do
		\mapfile -t Temporary < <(\printf "%s" "$(
			\gh api \
				-H "Accept: application/vnd.github+json" \
				-H "X-GitHub-Api-Version: 2022-11-28" \
				orgs/"${Organization}"/repos?per_page=100\&page=${Page} | \jq -r '.[].full_name'
		)" | \tr -d '\r')

		for Temporary in "${Temporary[@]}"; do
			Flag=false

			for RepositoryOmit in "${Omit[@]}"; do
				if [ "$Temporary" = "$RepositoryOmit" ]; then
					Flag=true

					break
				fi
			done

			if [ "$Flag" = false ]; then
				Repository+=("$Temporary")
			fi

			# TODO: Add these to the cache
			# Sync/Repository

			# ```sh
			# Main=$(\gh repo view --json parent | \jq -c -r '.parent.owner.login, .parent.name' | \tr -s '\r\n' '/')
			# Main=$(\echo "$Main" | \sed 's/\/$//')
			# Main=$(\gh repo view "$Main" --json defaultBranchRef | \jq -r -c '.defaultBranchRef.name')
			# ```

			# # Configure/Repository

			# ```sh
			# Upstream=$(\gh repo view --json parent | \jq -c -r '.parent.owner.login, .parent.name' | \tr -s '\r\n' '/')

			# if [[ "$Upstream" != "null/null" ]]; then
			# 	Upstream="ssh://git@github.com/${Upstream}"
			# 	Upstream=$(\echo "$Upstream" | \sed 's/\/$/\.git/')

			# 	\echo "Upstream: "
			# 	\echo "$Upstream"

			# 	\git remote remove upstream
			# 	\git remote add upstream "$Upstream"
			# 	\git remote set-url upstream "$Upstream"
			# fi
			# ```
		done
	done

	\mapfile -t Repository < <(\printf "%s\n" "${Repository[@]}" | \sort)

	\printf '%s\n' "${Repository[@]}" | jq -R . | jq -s . >"$Current"/../Service/"$Service".json
done
