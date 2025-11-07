const TGW_MAP: Record<string, string> = {
  'us-east-1': 'tgw-03937b0cffc35663b',
  'us-east-2': 'tgw-075e966ee7c6418d9',
  'us-west-1': 'tgw-0264d36851272bb6a',
  'us-west-2': 'tgw-0cba42d759bd3df2a',
};

const SHARED_SUBNET_ACCOUNTS = ['896232133429'];

interface TestTarget {
  host: string;
  port: number;
  protocol: 'tcp' | 'http' | 'https';
  path?: string;
}

const TEST_TARGETS: TestTarget[] = [
  { host: 'staging.customer-admin.api.rackspace.net', port: 443, protocol: 'https' },
  { host: 'admin.aws.customer.rackspace.net', port: 443, protocol: 'https' },
];

const REGIONS = ['us-east-1', 'us-east-2', 'us-west-1', 'us-west-2'];

export {
  TGW_MAP,
  TEST_TARGETS,
  REGIONS,
  SHARED_SUBNET_ACCOUNTS,
  type TestTarget,
};
