#!/bin/bash

# Test exalsius workspace Helm Charts Locally
# This script runs the same tests that the CI workflow performs

set -e

echo "Finding all Helm charts..."
charts=$(find workspace-templates -name "Chart.yaml" -type f | sed 's|/Chart.yaml||')

if [ -z "$charts" ]; then
    echo "ERROR: No Helm charts found in workspace-templates/"
    exit 1
fi

echo "Found charts:"
echo "$charts" | while read -r chart; do
    echo "  - $chart"
done

echo ""
echo "Testing each chart..."

# Test each chart
echo "$charts" | while read -r chart_path; do
    echo ""
    echo "================================"
    echo "Testing chart: $chart_path"
    echo "================================"
    
    # Check required files
    echo "Checking required files..."
    if [ ! -f "$chart_path/Chart.yaml" ]; then
        echo "ERROR: Chart.yaml not found"
        exit 1
    fi
    if [ ! -f "$chart_path/values.yaml" ]; then
        echo "ERROR: values.yaml not found"
        exit 1
    fi
    echo "SUCCESS: Required files present"
    
    # Validate Chart.yaml structure
    echo "Validating Chart.yaml structure..."
    if ! grep -q "apiVersion:" "$chart_path/Chart.yaml"; then
        echo "ERROR: Chart.yaml missing apiVersion"
        exit 1
    fi
    if ! grep -q "name:" "$chart_path/Chart.yaml"; then
        echo "ERROR: Chart.yaml missing name"
        exit 1
    fi
    if ! grep -q "version:" "$chart_path/Chart.yaml"; then
        echo "ERROR: Chart.yaml missing version"
        exit 1
    fi
    echo "SUCCESS: Chart.yaml structure is valid"
    
    # Lint chart
    echo "Linting chart..."
    helm lint "$chart_path" || {
        echo "ERROR: Helm lint failed for $chart_path"
        exit 1
    }
    echo "SUCCESS: Lint passed"
    
    # Check and update dependencies if they exist
    echo "Checking dependencies..."
    if grep -q "dependencies:" "$chart_path/Chart.yaml"; then
        echo "Updating dependencies..."
        helm dependency update "$chart_path" || {
            echo "ERROR: Dependency update failed for $chart_path"
            exit 1
        }
        echo "SUCCESS: Dependencies updated"
    else
        echo "No dependencies found, skipping"
    fi
    
    # Template chart
    echo "Templating chart..."
    helm template test-release "$chart_path" --dry-run || {
        echo "ERROR: Template generation failed for $chart_path"
        exit 1
    }
    echo "SUCCESS: Template generation passed"
    
    # Validate with values
    echo "Validating with values..."
    helm template test-release "$chart_path" --values "$chart_path/values.yaml" --dry-run || {
        echo "ERROR: Values validation failed for $chart_path"
        exit 1
    }
    echo "SUCCESS: Values validation passed"
    
    echo "SUCCESS: Chart $chart_path passed all tests"
done

echo ""
echo "SUCCESS: All charts passed testing!"
