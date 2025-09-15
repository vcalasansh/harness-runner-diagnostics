#!/bin/bash

# Pipeline load test script - runs curl 5 times, waits 5 minutes, repeats 5 cycles total

CURL_CMD="curl -X POST -H 'content-type: application/json' --url 'https://qa.harness.io/gateway/pipeline/api/webhook/custom/uafmWObeS4mfYreeFzSftA/v3?accountIdentifier=f_jaOpbtS1OzVdFfYVaN5w&orgIdentifier=default&projectIdentifier=RunnerDisneyTest&pipelineIdentifier=Golden_Test_Pipeline_Paypal_linux&triggerIdentifier=testlinuxrunner'"

echo "Starting pipeline load test: $(date)"
echo "Will run 5 cycles of (5 curl requests + 5 minute wait)"
echo "========================================="

for cycle in {1..5}; do
    echo ""
    echo "Cycle $cycle of 5 - $(date)"
    echo "Running 5 curl requests..."
    
    for request in {1..5}; do
        echo "  Request $request/5 - $(date +"%H:%M:%S")"
        eval $CURL_CMD
        echo ""
        
        # Small delay between individual requests (optional)
        sleep 2
    done
    
    # Wait 5 minutes before next cycle (except after the last cycle)
    if [ $cycle -lt 5 ]; then
        echo "Waiting 5 minutes before next cycle..."
        echo "Next cycle will start at: $(date -d '+5 minutes' '+%H:%M:%S')"
        sleep 300  # 5 minutes = 300 seconds
    fi
done

echo ""
echo "========================================="
echo "Load test completed: $(date)"
echo "Total requests sent: 25 (5 cycles × 5 requests)" 