import http from 'k6/http';
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { check, sleep } from 'k6';

export const options = {
  thresholds: {
    http_req_failed: ['rate<{{ .Values.scripts.spike.thresholds.http_req_failed }}'], 
    http_req_duration: ['p(95)<{{ .Values.scripts.spike.thresholds.http_req_duration }}'],
  },
  scenarios: {
    spike_test: {
      executor: 'ramping-vus',
      stages: [
        {{- range .Values.scripts.spike.scenarios.stages }}
        { duration: '{{ .duration }}', target: {{ .target }} },
        {{- end }}
      ],
      gracefulRampDown: '10s'
    },
  },
};

const firstNames = ['Test', 'Load', 'Spike', 'Demo', 'User'];
const lastNames = ['Customer', 'User', 'Account', 'Profile', 'Record'];

function generateSpikeCustomerData() {
  const firstName = randomItem(firstNames);
  const lastName = randomItem(lastNames);
  const timestamp = Date.now();
  
  return {
    name: `${firstName} ${lastName} ${randomString(4)}`,
    email: `spike.${timestamp}.${randomString(6)}@loadtest.com`,
    phone: `+1-555-${String(randomIntBetween(1000, 9999))}`,
    address: `${randomIntBetween(1, 999)} Spike St, Load City, TX ${String(randomIntBetween(10000, 99999))}`
  };
}

export default function () {
  const baseUrl = 'http://{{ .Values.target.service }}:{{ .Values.target.port }}';
  const customer = generateSpikeCustomerData();
  
  const response = http.post(`${baseUrl}/api/customers`, JSON.stringify(customer), {
    headers: { 'Content-Type': 'application/json' },
    tags: { operation: 'spike_create' },
  });
  
  check(response, {
    'spike request completes': (r) => r.status !== 0,
    'spike request under 10s': (r) => r.timings.duration < 10000,
  });
  
  sleep(0.5);
}