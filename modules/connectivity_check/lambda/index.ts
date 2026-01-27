import { Socket } from 'node:net';
import { lookup } from 'node:dns/promises';

const stats = require('@racker/janus-core/lib/stats');
const log = require('@racker/janus-core/lib/log');

interface TestTarget {
  host: string;
  port: number;
  protocol: 'tcp' | 'http' | 'https';
  path?: string;
  critical?: boolean;
}

interface TestResult {
  host: string;
  port: number;
  protocol: string;
  success: boolean;
  latencyMs?: number;
  resolvedIp?: string;
  error?: string;
  errorCode?: string;
  httpStatus?: number;
  critical?: boolean;
}

interface LambdaEvent {
  targets: TestTarget[];
}

export const handler = async (event: LambdaEvent): Promise<TestResult[]> => {
  const env = process.env.JANUS_ENVIRONMENT || 'unknown';
  
  log.initialize('connectivity-check', {
    level: env === 'local' ? 'debug' : 'info'
  });

  try {
    // Initialize Datadog stats
    await stats.initializeWithDriver('http', 'connectivity.', {
      defaultTags: [
        `env:${env}`,
        'service:connectivity-check'
      ],
      mock: ['local', 'test'].includes(env)
    });

    log.info(
      { targetCount: event.targets.length },
      'Testing connectivity for targets'
    );

    const results: TestResult[] = [];

    for (const target of event.targets) {
      let result: TestResult;
      
      if (target.protocol === 'tcp') {
        result = await testTcp(target);
      } else if (target.protocol === 'http' || target.protocol === 'https') {
        result = await testHttp(target);
      } else {
        result = {
          host: target.host,
          port: target.port,
          protocol: target.protocol,
          success: false,
          error: `Unsupported protocol: ${target.protocol}`,
          critical: target.critical,
        };
      }
      
      results.push(result);

      // Publish metrics to Datadog
      publishMetrics(result);
    }

    log.info({ successCount: results.filter(r => r.success).length, totalCount: results.length }, 'Connectivity check complete');

    return results;
  } finally {
    await stats.close();
  }
};

function isIpAddress(host: string): boolean {
  // Simple check for IPv4
  return /^(\d{1,3}\.){3}\d{1,3}$/.test(host);
}

async function resolveDns(
  host: string
): Promise<{
  success: boolean;
  ip?: string;
  error?: string;
  errorCode?: string;
  latencyMs: number;
}> {
  if (isIpAddress(host)) {
    return { success: true, ip: host, latencyMs: 0 };
  }

  const start = Date.now();
  try {
    const result = await lookup(host);
    return {
      success: true,
      ip: result.address,
      latencyMs: Date.now() - start,
    };
  } catch (err: any) {
    return {
      success: false,
      error: err.message,
      errorCode: err.code,
      latencyMs: Date.now() - start,
    };
  }
}

async function testTcp(target: TestTarget): Promise<TestResult> {
  const start = Date.now();

  // DNS resolution first
  const dnsResult = await resolveDns(target.host);
  if (!dnsResult.success) {
    return {
      host: target.host,
      port: target.port,
      protocol: 'tcp',
      success: false,
      error: `DNS resolution failed: ${dnsResult.error}`,
      errorCode: dnsResult.errorCode,
      critical: target.critical,
    };
  }

  return new Promise((resolve) => {
    const socket = new Socket();
    const timeout = 5000;

    socket.setTimeout(timeout);

    socket.on('connect', () => {
      socket.destroy();
      resolve({
        host: target.host,
        port: target.port,
        protocol: 'tcp',
        success: true,
        resolvedIp: dnsResult.ip,
        latencyMs: Date.now() - start,
        critical: target.critical,
      });
    });

    socket.on('timeout', () => {
      socket.destroy();
      resolve({
        host: target.host,
        port: target.port,
        protocol: 'tcp',
        success: false,
        resolvedIp: dnsResult.ip,
        error: 'Connection timeout (5s)',
        errorCode: 'ETIMEDOUT',
        critical: target.critical,
      });
    });

    socket.on('error', (err: any) => {
      socket.destroy();
      resolve({
        host: target.host,
        port: target.port,
        protocol: 'tcp',
        success: false,
        resolvedIp: dnsResult.ip,
        error: err.message,
        errorCode: err.code,
        critical: target.critical,
      });
    });

    socket.connect(target.port, target.host);
  });
}

async function testHttp(target: TestTarget): Promise<TestResult> {
  const start = Date.now();

  // DNS resolution first
  const dnsResult = await resolveDns(target.host);
  if (!dnsResult.success) {
    return {
      host: target.host,
      port: target.port,
      protocol: target.protocol,
      success: false,
      error: `DNS resolution failed: ${dnsResult.error}`,
      errorCode: dnsResult.errorCode,
      critical: target.critical,
    };
  }

  const url = `${target.protocol}://${target.host}:${target.port}${
    target.path || '/'
  }`;

  try {
    const response = await fetch(url, {
      method: 'GET',
      signal: AbortSignal.timeout(5000),
    });

    // Log response details
    const headers = Object.fromEntries(response.headers.entries());
    log.debug({ url, headers }, 'HTTP response headers');

    const bodyText = await response.text();
    const truncatedBody =
      bodyText.length > 100
        ? bodyText.substring(0, 100) + '...(truncated)'
        : bodyText;
    log.debug({ url, body: truncatedBody }, 'HTTP response body');

    return {
      host: target.host,
      port: target.port,
      protocol: target.protocol,
      success: true, // we don't really care about status code, just connectivity
      resolvedIp: dnsResult.ip,
      latencyMs: Date.now() - start,
      httpStatus: response.status,
      critical: target.critical,
    };
  } catch (err: any) {
    return {
      host: target.host,
      port: target.port,
      protocol: target.protocol,
      success: false,
      resolvedIp: dnsResult.ip,
      error: err.message,
      errorCode: err.code || err.cause?.code,
      critical: target.critical,
    };
  }
}

/**
 * Publish connectivity metrics to Datadog via janus-core stats
 */
function publishMetrics(result: TestResult): void {
  const endpoint = `${result.host}:${result.port}`;
  const tags = [
    `endpoint:${endpoint}`,
    `host:${result.host}`,
    `protocol:${result.protocol}`,
    `critical:${result.critical || false}`,
  ];

  // Connectivity status metric (1 = success, 0 = failure)
  stats.gauge('endpoint.status', result.success ? 1 : 0, tags);

  // Response time metric
  if (result.latencyMs !== undefined) {
    stats.gauge('endpoint.latency', result.latencyMs, tags);
  }

  // Count metrics for success/failure
  if (result.success) {
    stats.increment('endpoint.success.count', 1, tags);
  } else {
    stats.increment('endpoint.error.count', 1, tags);
    if (result.errorCode) {
      stats.increment('endpoint.error.count', 1, [...tags, `error_code:${result.errorCode}`]);
    }
  }
}
