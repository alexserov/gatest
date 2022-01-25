paginate () { # "method" "URL" "items getter"
    local result="[]"
    local page=0
    while true
    do
        ((page++))
        local value=$(echo $(curl -s -X $1 $2 -H "Accept: application/vnd.github.v3+json" -G -H "Authorization: Bearer ${{github.token}}" -d per_page=100 -d page=$page) | jq $3)
        if [ $(echo $value | jq -r ". | length") == 0 ]; then
            echo $result
            return 0
        fi
        result=$(echo '{"a": '$result', "b": '$value'}' | jq '.a + .b')
    done

    echo "exit"
    echo $result
}


all_requests=$(paginate GET "https://api.github.com/repos/${{github.repository}}/pulls?state=open")
renovate_request_refs=$(echo $all_requests | jq 'map(select(.user.login | contains("renovate"))) | .[] | .head.ref')

for request_ref in $(echo $renovate_request_refs | jq -r .); do
    all_checks=$(paginate GET "https://api.github.com/repos/${{github.repository}}/commits/$request_ref/check-runs" .check_runs)
    failed_checks=$(echo $all_checks | jq 'map(select((.conclusion != null) and (.conclusion | contains("failure"))))')

    for check_id in $(echo $failed_checks | jq -r .[].check_suite.id); do
        curl -X POST \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: Bearer ${{github.token}}" \
            "https://api.github.com/repos/${{github.repository}}/check-suites/${check_id}/rerequest"
    done
done
