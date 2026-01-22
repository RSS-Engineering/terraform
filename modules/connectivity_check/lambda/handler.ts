import { Socket } from 'node:net';
import { lookup } from 'node:dns/promises';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';

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
  publishMetrics?: boolean;
  cloudwatchNamespace?: string;
}

export const handler = async (event: LambdaEvent): Promise<TestResult[]> => {
  console.log(
    'Testing connectivity for targets:',
    JSON.stringify(event.targets)
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
  }

  console.log('Results:', JSON.stringify(results));

  // Publish metrics to CloudWatch if enabled
  if (event.publishMetrics) {
    await publishMetrics(results, event.cloudwatchNamespace || 'ConnectivityCheck');
  }

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
 * Publish connectivity metrics to CloudWatch
 */
async function publishMetrics(
  results: TestResult[],
  namespace: string
): Promise<void> {
  const cloudwatch = new CloudWatchClient({});
  const functionName = process.env.AWS_LAMBDA_FUNCTION_NAME || 'unknown';
  const timestamp = new Date();

  const metricData = [];

  for (const result of results) {
    const endpoint = `${result.host}:${result.port}`;

    // Connectivity metric (1 = success, 0 = failure)
    metricData.push({
      MetricName: 'EndpointConnectivity',
      Dimensions: [
        { Name: 'FunctionName', Value: functionName },
        { Name: 'Endpoint', Value: endpoint },
        { Name: 'Critical', Value: String(result.critical || false) },
      ],
      Value: result.success ? 1.0 : 0.0,
      Unit: 'None',
      Timestamp: timestamp,
    });

    // Response time metric
    if (result.latencyMs !== undefined) {
      metricData.push({
        MetricName: 'EndpointLatency',
        Dimensions: [
          { Name: 'FunctionName', Value: functionName },
          { Name: 'Endpoint', Value: endpoint },
        ],
        Value: result.latencyMs,
        Unit: 'Milliseconds',
        Timestamp: timestamp,
      });
    }
  }

  // Publish in batches of 20 (CloudWatch limit)
  for (let i = 0; i < metricData.length; i += 20) {
    const batch = metricData.slice(i, i + 20);
    const command = new PutMetricDataCommand({
      Namespace: namespace,
      MetricData: batch,
    });

    try {
      await cloudwatch.send(command);
    } catch (err) {
      console.error('Failed to publish metrics:', err);
      // Don't fail the Lambda if metrics publishing fails
    }
  }

  console.log(
    `Published ${metricData.length} metrics to CloudWatch namespace: ${namespace}`
  );
}
