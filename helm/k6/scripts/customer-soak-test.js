import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

export const options = {
  thresholds: {
    http_req_failed: ['rate<{{ .Values.scripts.soak.thresholds.http_req_failed }}'],
    http_req_duration: ['p(95)<{{ .Values.scripts.soak.thresholds.http_req_duration }}'],
    'http_req_duration{expected_response:true}': ['p(95) < 500'],
  },
  scenarios: {
    soak_test: {
      executor: 'constant-vus',
      vus: {{ .Values.scripts.soak.scenarios.vus }}, 
      duration: '{{ .Values.scripts.soak.scenarios.duration }}', 
      gracefulStop: '30s'
    },
  },
};

export default function () {
  const baseUrl = 'http://{{ .Values.target.service }}:{{ .Values.target.port }}';
  
  const response = http.get(`${baseUrl}/api/customers`, {
    tags: { operation: 'get_all_customers' },
  });
  
  check(response, {
    'get all customers status is 200': (r) => r.status === 200,
    'get all customers response time < 1s': (r) => r.timings.duration < 1000,
    'response contains customers array': (r) => {
      if (r.status === 200) {
        try {
          const customers = JSON.parse(r.body);
          return Array.isArray(customers);
        } catch (e) {
          return false;
        }
      }
      return true;
    },
    'response body is valid JSON': (r) => {
      if (r.status === 200) {
        try {
          JSON.parse(r.body);
          return true;
        } catch (e) {
          return false;
        }
      }
      return true;
    },
  });
  
  sleep(randomIntBetween(0, 2));
}