import http from 'k6/http';
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { check, sleep } from 'k6';

export const options = {
  thresholds: {
    http_req_failed: ['rate<{{ .Values.scripts.load.thresholds.http_req_failed }}'],
    http_req_duration: ['p(95)<{{ .Values.scripts.load.thresholds.http_req_duration }}'],
    'http_req_duration{expected_response:true}': ['p(95) <500'],
  },
  scenarios: {
    load_test: {
      executor: 'ramping-vus',
      stages: [
        {{- range .Values.scripts.load.scenarios.stages }}
        { duration: '{{ .duration }}', target: {{ .target }} },
        {{- end }}
      ],
      gracefulRampDown: '10s'
    },
  },
};

const firstNames = ['John', 'Jane', 'Michael', 'Sarah', 'David', 'Lisa', 'Chris', 'Emma', 'Alex', 'Maria'];
const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez'];
const domains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'company.com', 'test.org', 'demo.net'];

function generateCustomerData() {
  const firstName = randomItem(firstNames);
  const lastName = randomItem(lastNames);
  const domain = randomItem(domains);
  
  const name = `${firstName} ${lastName}`;
  const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}.${randomString(3)}@${domain}`;
  const phone = `+1-${randomIntBetween(100, 999)}-${randomIntBetween(100, 999)}-${String(randomIntBetween(1000, 9999))}`;
  const address = `${randomIntBetween(1, 9999)} Main St, Test City, TX ${String(randomIntBetween(10000, 99999))}`;
  
  return { name, email, phone, address };
}

export default function () {
  const baseUrl = 'http://{{ .Values.target.service }}:{{ .Values.target.port }}';
  const customer = generateCustomerData();
  
  const createResponse = http.post(`${baseUrl}/api/customers`, JSON.stringify(customer), {
    headers: { 'Content-Type': 'application/json' },
    tags: { operation: 'create_customer' },
  });
  
  const createSuccess = check(createResponse, {
    'customer creation status is 201': (r) => r.status === 201,
    'customer creation response time < 3s': (r) => r.timings.duration < 3000,
    'customer has valid ID': (r) => {
      if (r.status === 201) {
        const body = JSON.parse(r.body);
        return body.id && typeof body.id === 'number';
      }
      return true;
    },
  });
  
  if (createSuccess && createResponse.status === 201) {
    const createdCustomer = JSON.parse(createResponse.body);
    sleep(0.1);
    
    const getResponse = http.get(`${baseUrl}/api/customers/${createdCustomer.id}`, {
      tags: { operation: 'get_customer' },
    });
    
    check(getResponse, {
      'customer retrieval status is 200': (r) => r.status === 200,
      'customer retrieval response time < 2s': (r) => r.timings.duration < 2000,
      'retrieved customer matches created': (r) => {
        if (r.status === 200) {
          const retrieved = JSON.parse(r.body);
          return retrieved.name === customer.name && retrieved.email === customer.email;
        }
        return true;
      },
    });
  }
  
  sleep(randomIntBetween(1, 3));
}