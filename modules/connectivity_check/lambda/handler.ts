import { Socket } from 'node:net';
import { lookup } from 'node:dns/promises';

interface TestTarget {
  host: string;
  port: number;
  protocol: 'tcp' | 'http' | 'https';
  path?: string;
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
}

interface LambdaEvent {
  targets: TestTarget[];
}

export const handler = async (event: LambdaEvent): Promise<TestResult[]> => {
  console.log(
    'Testing connectivity for targets:',
    JSON.stringify(event.targets)
  );

  const results: TestResult[] = [];

  for (const target of event.targets) {
    if (target.protocol === 'tcp') {
      results.push(await testTcp(target));
    } else if (target.protocol === 'http' || target.protocol === 'https') {
      results.push(await testHttp(target));
    } else {
      results.push({
        host: target.host,
        port: target.port,
        protocol: target.protocol,
        success: false,
        error: `Unsupported protocol: ${target.protocol}`,
      });
    }
  }

  console.log('Results:', JSON.stringify(results));
  return results;
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
    console.log(`Response headers for ${url}:`, JSON.stringify(headers));

    const bodyText = await response.text();
    const truncatedBody =
      bodyText.length > 100
        ? bodyText.substring(0, 100) + '...(truncated)'
        : bodyText;
    console.log(`Response body for ${url}:`, truncatedBody);

    return {
      host: target.host,
      port: target.port,
      protocol: target.protocol,
      success: true, // we don't really care about status code, just connectivity
      resolvedIp: dnsResult.ip,
      latencyMs: Date.now() - start,
      httpStatus: response.status,
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
    };
  }
}
