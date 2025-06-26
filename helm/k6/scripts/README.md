# K6 Test Scripts

This directory contains the K6 JavaScript test scripts that are loaded into the Kubernetes ConfigMap for testing.

## Scripts

- **customer-load-test.js** - Load testing with ramping virtual users, creates and retrieves customers
- **customer-spike-test.js** - Spike testing with rapid load increases 
- **customer-soak-test.js** - Soak testing with constant load over extended duration

## Helm Template Variables

The scripts use Helm template variables that are replaced at deployment time:

- `{{ .Values.target.service }}` - Target service name
- `{{ .Values.target.port }}` - Target service port
- `{{ .Values.scripts.*.thresholds.* }}` - Performance thresholds
- `{{ .Values.scripts.*.scenarios.* }}` - Test scenario configuration

## Editing Scripts

1. Edit the JavaScript files in this directory
2. Test with `helm template .` from the parent directory
3. Deploy with `./install.ps1` to see changes in action

The ConfigMap template automatically loads these files using `{{ .Files.Get }}` function.